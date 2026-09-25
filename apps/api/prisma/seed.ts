// Seeds places and plan prices (idempotent). Run: npm run prisma:seed -w @rido/api
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../src/generated/prisma/client.js';
import type { PlanPeriod, VehicleKind } from '../src/generated/prisma/enums.js';
import { PLAN_PRICES } from '../src/modules/subscriptions/plan-prices.js';
import { cellAt, cellsForCircle } from '../src/modules/geo/h3.util.js';

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL ?? '' }) });

const PLACES = [
  ['gandhipuram', 'Gandhipuram Central Bus Stand', 'Cross Cut Rd, Gandhipuram', 11.0183, 76.9725],
  ['brookefields', 'Brookefields Mall', 'Krishnasamy Rd, RS Puram', 11.009, 76.96],
  ['brookefields-plaza', 'Brookefields Plaza', 'Brookebond Rd, RS Puram', 11.0096, 76.9612],
  ['brookebond-road', 'Brookebond Road', 'Saibaba Colony', 11.0112, 76.9575],
  ['rs-puram', 'RS Puram', 'DB Rd, RS Puram', 11.0089, 76.95],
  ['peelamedu', 'Peelamedu', 'Avinashi Rd, Peelamedu', 11.029, 77.027],
  ['psg-tech', 'PSG Tech', 'Avinashi Rd, Peelamedu', 11.0247, 77.0028],
  ['junction', 'Coimbatore Junction', 'State Bank Rd, Gopalapuram', 10.996, 76.966],
  ['airport', 'Coimbatore International Airport', 'Avinashi Rd, Civil Aerodrome', 11.03, 77.0434],
  ['tidel-park', 'Tidel Park', 'ELCOT SEZ, Vilankurichi Rd', 11.031, 77.028],
  ['race-course', 'Race Course', 'Race Course Rd, Coimbatore', 10.999, 76.978],
  ['saibaba-colony', 'Saibaba Colony', 'NSR Rd, Saibaba Colony', 11.024, 76.944],
  ['prozone', 'Prozone Mall', 'Sathy Rd, Saravanampatti', 11.055, 76.995],
  ['ukkadam', 'Ukkadam', 'Palakkad Rd, Ukkadam', 10.988, 76.961],
  ['town-hall', 'Town Hall', 'Big Bazaar St, Town Hall', 10.993, 76.961],
  ['singanallur', 'Singanallur', 'Trichy Rd, Singanallur', 10.999, 77.029],
  ['vellalore', 'Vellalore', 'Vellalore Rd, Podanur', 10.9545, 77.0076],
] as const;

async function main(): Promise<void> {
  for (const [id, name, address, lat, lng] of PLACES) {
    await prisma.place.upsert({ where: { id }, create: { id, name, address, lat, lng }, update: { name, address, lat, lng } });
  }
  for (const [vehicleKind, periods] of Object.entries(PLAN_PRICES)) {
    for (const [period, price] of Object.entries(periods)) {
      const key = { vehicleKind: vehicleKind as VehicleKind, period: period as PlanPeriod };
      await prisma.plan.upsert({ where: { vehicleKind_period: key }, create: { ...key, price }, update: { price } });
    }
  }
  await seedCoimbatore();
  await backfillTripCells();
  console.log(`Seeded ${PLACES.length} places, ${Object.keys(PLAN_PRICES).length * 3} plans and the Coimbatore service area`);
}

/** Coimbatore: H3 resolution 8, 18 km around the centre, 3 demand zones. Only created once (admin edits win). */
async function seedCoimbatore(): Promise<void> {
  const existing = await prisma.city.findUnique({ where: { id: 'coimbatore' } });
  if (existing) return;
  const res = 8;
  await prisma.city.create({
    data: {
      id: 'coimbatore',
      name: 'Coimbatore',
      state: 'Tamil Nadu',
      centerLat: 11.0168,
      centerLng: 76.9658,
      h3Resolution: res,
      serviceCells: cellsForCircle({ lat: 11.0168, lng: 76.9658, radiusKm: 18, resolution: res }),
      zones: {
        create: [
          { name: 'Gandhipuram', lat: 11.0183, lng: 76.9725 },
          { name: 'Peelamedu', lat: 11.029, lng: 77.027 },
          { name: 'RS Puram', lat: 11.0089, lng: 76.95 },
        ].map((z) => ({ name: `High demand: ${z.name}`, kind: 'DEMAND' as const, cells: cellsForCircle({ lat: z.lat, lng: z.lng, radiusKm: 0.8, resolution: res }), color: '#F4511E' })),
      },
    },
  });
}

/** Fills pickup/drop H3 cells for trips created before heatmaps existed. */
async function backfillTripCells(): Promise<void> {
  const trips = await prisma.trip.findMany({ where: { OR: [{ pickupCell: null }, { dropCell: null }] }, select: { id: true, pickupLat: true, pickupLng: true, dropLat: true, dropLng: true } });
  for (const t of trips) {
    await prisma.trip.update({ where: { id: t.id }, data: { pickupCell: cellAt(t.pickupLat, t.pickupLng, 8), dropCell: cellAt(t.dropLat, t.dropLng, 8) } });
  }
  if (trips.length) console.log(`Backfilled H3 cells on ${trips.length} trips`);
}

await main();
await prisma.$disconnect();
