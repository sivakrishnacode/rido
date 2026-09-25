// Demo trips for heatmaps and dashboards (opt-in). Ids start with "demo_" so they can be removed.
//   npm run seed:demo-trips -w @rido/api            # add ~2,000 trips over the last 30 days
//   npm run seed:demo-trips -w @rido/api -- --clear # remove them
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../src/generated/prisma/client.js';
import type { TripStatus, VehicleKind } from '../src/generated/prisma/enums.js';
import { estimateRoute, quoteFare } from '../src/modules/fares/fare-engine.js';
import { cellAt } from '../src/modules/geo/h3.util.js';

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL ?? '' }) });

/** Hotspots with relative demand weight. */
const HOTSPOTS = [
  { name: 'Gandhipuram', lat: 11.0183, lng: 76.9725, w: 20 },
  { name: 'Peelamedu', lat: 11.029, lng: 77.027, w: 14 },
  { name: 'RS Puram', lat: 11.0089, lng: 76.95, w: 10 },
  { name: 'Town Hall', lat: 10.993, lng: 76.961, w: 10 },
  { name: 'Coimbatore Junction', lat: 10.996, lng: 76.966, w: 9 },
  { name: 'Tidel Park', lat: 11.031, lng: 77.028, w: 8 },
  { name: 'Prozone Mall', lat: 11.055, lng: 76.995, w: 7 },
  { name: 'Ukkadam', lat: 10.988, lng: 76.961, w: 6 },
  { name: 'Singanallur', lat: 10.999, lng: 77.029, w: 6 },
  { name: 'Saibaba Colony', lat: 11.024, lng: 76.944, w: 5 },
  { name: 'Airport', lat: 11.03, lng: 77.0434, w: 3 },
  { name: 'Vellalore', lat: 10.9545, lng: 77.0076, w: 2 },
] as const;

/** Relative bookings per IST hour (morning and evening peaks). */
const HOUR_WEIGHT = [1, 0.5, 0.3, 0.2, 0.3, 1, 3, 6, 9, 8, 5, 4, 5, 5, 4, 4, 5, 8, 10, 9, 7, 5, 3, 2];
const VEHICLES: [VehicleKind, number][] = [['BIKE', 50], ['AUTO', 30], ['CAB', 12], ['GOODS_BIKE', 4], ['THREE_WHEELER', 3], ['MINI_TRUCK', 1]];

function pick<T>(items: readonly T[], weight: (t: T) => number): T {
  const total = items.reduce((a, t) => a + weight(t), 0);
  let r = Math.random() * total;
  for (const t of items) if ((r -= weight(t)) <= 0) return t;
  return items[items.length - 1];
}

/** Gaussian-ish offset in km around a point. */
function jitter(p: { lat: number; lng: number }, km: number): { lat: number; lng: number } {
  const g = (): number => (Math.random() + Math.random() + Math.random() - 1.5) / 1.5;
  return { lat: p.lat + (g() * km) / 111, lng: p.lng + (g() * km) / (111 * Math.cos((p.lat * Math.PI) / 180)) };
}

async function main(): Promise<void> {
  if (process.argv.includes('--clear')) {
    const { count } = await prisma.trip.deleteMany({ where: { id: { startsWith: 'demo_' } } });
    console.log(`Removed ${count} demo trips`);
    return;
  }
  const passenger = await prisma.user.upsert({
    where: { phone: '+919999900000' },
    create: { phone: '+919999900000', name: 'Demo passenger' },
    update: {},
  });
  const count = Number(process.argv.find((a) => /^\d+$/.test(a)) ?? 2000);
  const now = Date.now();
  const rows = [];
  for (let i = 0; i < count; i++) {
    const day = Math.floor(Math.random() * 30);
    const hour = HOUR_WEIGHT.indexOf(pick(HOUR_WEIGHT, (w) => w));
    const created = new Date(now - day * 86_400_000);
    // Set the IST hour (UTC+5:30).
    created.setUTCHours((hour + 24 - 5) % 24, Math.floor(Math.random() * 60) + 30 - 30, 0, 0);
    const from = pick(HOTSPOTS, (h) => h.w);
    let to = pick(HOTSPOTS, (h) => h.w);
    if (to.name === from.name) to = HOTSPOTS[(HOTSPOTS.indexOf(from) + 3) % HOTSPOTS.length];
    const pickup = jitter(from, 0.9);
    const drop = jitter(to, 0.9);
    const [vehicleKind] = pick(VEHICLES, ([, w]) => w);
    const isParcel = vehicleKind === 'GOODS_BIKE' || vehicleKind === 'THREE_WHEELER' || vehicleKind === 'MINI_TRUCK';
    const r = Math.random();
    const status: TripStatus = r < 0.07 ? 'NO_DRIVERS' : r < 0.15 ? 'CANCELLED' : isParcel ? 'DELIVERED' : 'COMPLETED';
    const q = quoteFare({ vehicleKind, route: estimateRoute(pickup, drop) });
    // Realistic trip times: slower in the morning/evening peaks (for learned hex-to-hex speeds).
    const isPeak = (hour >= 8 && hour <= 10) || (hour >= 17 && hour <= 20);
    const kmh = (isPeak ? 13 : 21) * (0.8 + Math.random() * 0.4);
    const isFinished = status === 'COMPLETED' || status === 'DELIVERED';
    const startedAt = isFinished ? new Date(created.getTime() + (4 + Math.random() * 4) * 60_000) : null;
    const endedAt = startedAt ? new Date(startedAt.getTime() + (q.distanceKm / kmh) * 3_600_000) : null;
    rows.push({
      id: `demo_${now.toString(36)}_${i}`,
      kind: isParcel ? ('PARCEL' as const) : ('RIDE' as const),
      status,
      passengerId: passenger.id,
      vehicleKind,
      pickupName: from.name, pickupAddr: from.name, pickupLat: pickup.lat, pickupLng: pickup.lng,
      dropName: to.name, dropAddr: to.name, dropLat: drop.lat, dropLng: drop.lng,
      pickupCell: cellAt(pickup.lat, pickup.lng, 8), dropCell: cellAt(drop.lat, drop.lng, 8),
      distanceKm: q.distanceKm, durationMin: q.durationMin, fare: q as object, fareTotal: q.total,
      otp: '0000', createdAt: created, startedAt, endedAt,
      cancelReason: status === 'CANCELLED' ? 'Changed my plan' : null,
    });
  }
  await prisma.trip.createMany({ data: rows });
  console.log(`Added ${rows.length} demo trips (last 30 days)`);
}

await main();
await prisma.$disconnect();
