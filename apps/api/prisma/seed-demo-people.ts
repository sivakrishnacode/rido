// Demo passengers, drivers (KYC, subscriptions, payments) and support tickets (opt-in). Ids start with "demo_".
// Run after seed-demo-trips: demo trips are spread across these passengers and finished ones get a driver.
//   npm run seed:demo-people -w @rido/api            # add (idempotent)
//   npm run seed:demo-people -w @rido/api -- --clear # remove them
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../src/generated/prisma/client.js';
import type { DriverStatus, KycDocType, KycStatus, PlanPeriod, SubscriptionStatus, VehicleKind } from '../src/generated/prisma/enums.js';

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL ?? '' }) });

const FIRST = ['Arun', 'Priya', 'Karthik', 'Divya', 'Suresh', 'Lakshmi', 'Vignesh', 'Meena', 'Rajesh', 'Kavya', 'Prakash', 'Anitha', 'Senthil', 'Revathi', 'Mani', 'Deepa', 'Gokul', 'Nandhini', 'Bala', 'Sangeetha'];
const LAST = ['Kumar', 'Raj', 'Subramani', 'Murugan', 'Selvam', 'Natarajan', 'Krishnan', 'Pandian', 'Ramasamy', 'Velu'];
const MODELS: Record<string, string[]> = {
  BIKE: ['Honda Activa 6G', 'TVS Jupiter', 'Hero Splendor+', 'Bajaj Pulsar 150'],
  AUTO: ['Bajaj RE Compact', 'Piaggio Ape City', 'TVS King'],
  CAB: ['Maruti Dzire', 'Hyundai Aura', 'Toyota Etios'],
  GOODS_BIKE: ['TVS XL100', 'Hero Splendor+'],
  THREE_WHEELER: ['Piaggio Ape Xtra', 'Bajaj Maxima Cargo'],
  MINI_TRUCK: ['Tata Ace Gold', 'Mahindra Jeeto'],
};
const COLORS = ['White', 'Black', 'Red', 'Blue', 'Grey', 'Yellow'];
// [vehicle, count] - approved drivers are needed for every vehicle the demo trips use.
const FLEET: [VehicleKind, number][] = [['BIKE', 12], ['AUTO', 8], ['CAB', 5], ['GOODS_BIKE', 3], ['THREE_WHEELER', 2], ['MINI_TRUCK', 2]];
const DOCS: KycDocType[] = ['DRIVING_LICENCE', 'AADHAAR', 'VEHICLE_RC', 'INSURANCE', 'POLICE_VERIFICATION'];
const TOPICS: [string, string][] = [
  ['Fare issue', 'I was charged more than the quoted fare.'],
  ['Driver behaviour', 'The driver asked me to cancel and pay cash outside the app.'],
  ['Lost item', 'I left my bag in the vehicle. Please help me contact the driver.'],
  ['Payment', 'UPI payment was debited but the trip shows unpaid.'],
  ['App problem', 'The app keeps showing searching even after a driver accepted.'],
  ['Safety', 'The driver was driving too fast on Avinashi Road.'],
];

let seq = 0;
const rand = <T>(a: readonly T[]): T => a[Math.floor(Math.random() * a.length)];
const name = (): string => `${FIRST[seq % FIRST.length]} ${LAST[Math.floor(seq / 2) % LAST.length]}`;
const daysAgo = (d: number): Date => new Date(Date.now() - d * 86_400_000);

async function clear(): Promise<void> {
  const demo = { startsWith: 'demo_' };
  // Demo trips belong to the demo passenger from seed-demo-trips again; real trips are never touched.
  const owner = await prisma.user.findUnique({ where: { phone: '+919999900000' } });
  if (owner) await prisma.trip.updateMany({ where: { id: demo }, data: { passengerId: owner.id, driverId: null } });
  await prisma.supportTicket.deleteMany({ where: { id: demo } });
  await prisma.trip.updateMany({ where: { driverId: demo }, data: { driverId: null } });
  const { count } = await prisma.user.deleteMany({ where: { id: demo } }); // cascades drivers, KYC, subscriptions, payments
  console.log(`Removed ${count} demo users with their drivers, KYC, subscriptions and tickets`);
}

async function main(): Promise<void> {
  if (process.argv.includes('--clear')) return clear();
  if (await prisma.user.findFirst({ where: { id: { startsWith: 'demo_' } } })) {
    console.log('Demo people already seeded (run with --clear first to recreate)');
    return;
  }

  // Passengers
  const passengers: string[] = [];
  for (let i = 0; i < 40; i++, seq++) {
    const id = `demo_p${i}`;
    await prisma.user.create({
      data: {
        id, phone: `+91970000${String(10000 + i).slice(1)}`, name: name(), role: 'PASSENGER',
        gender: rand(['FEMALE', 'MALE', 'MALE'] as const), createdAt: daysAgo(30 + Math.random() * 60),
        isBlocked: i === 7, blockedReason: i === 7 ? 'Repeated no-shows' : null,
      },
    });
    passengers.push(id);
  }

  // Drivers: mostly approved, some pending review, a few rejected / on hold.
  const plans = await prisma.plan.findMany();
  let d = 0;
  for (const [vehicleKind, n] of FLEET) {
    for (let k = 0; k < n; k++, d++, seq++) {
      const id = `demo_d${d}`;
      const status: DriverStatus = k < n - 2 || n <= 2 ? 'APPROVED' : d % 3 === 0 ? 'REJECTED' : d % 2 ? 'PENDING' : 'ON_HOLD';
      const approved = status === 'APPROVED';
      await prisma.user.create({
        data: {
          id, phone: `+91980000${String(10000 + d).slice(1)}`, name: name(), role: 'DRIVER', gender: d % 5 === 0 ? 'FEMALE' : 'MALE',
          createdAt: daysAgo(40 + Math.random() * 90),
          driver: {
            create: {
              id, vehicleKind, workType: ['GOODS_BIKE', 'THREE_WHEELER', 'MINI_TRUCK'].includes(vehicleKind) ? 'DELIVERIES' : 'RIDES',
              vehicleModel: rand(MODELS[vehicleKind]), vehicleColor: rand(COLORS),
              plate: `TN 37 ${String.fromCharCode(65 + (d % 26))}${String.fromCharCode(65 + ((d * 7) % 26))} ${1000 + d * 37}`,
              upiId: `demo${d}@okaxis`, status, isOnline: approved && d % 3 !== 0,
              rating: approved ? Math.round((4.2 + Math.random() * 0.8) * 10) / 10 : 5,
              documents: {
                create: DOCS.map((type, j) => {
                  const kyc: KycStatus = approved ? 'VERIFIED'
                    : status === 'REJECTED' && j === 0 ? 'REJECTED'
                    : status === 'PENDING' ? (j < 3 ? 'UNDER_REVIEW' : 'NOT_UPLOADED')
                    : j < 4 ? 'VERIFIED' : 'UNDER_REVIEW';
                  return { type, status: kyc, rejectReason: kyc === 'REJECTED' ? 'Licence photo is blurred' : null };
                }),
              },
            },
          },
        },
      });

      if (!approved) continue;
      const period: PlanPeriod = rand(['DAILY', 'WEEKLY', 'WEEKLY', 'MONTHLY'] as const);
      const plan = plans.find((p) => p.vehicleKind === vehicleKind && p.period === period);
      if (!plan) continue;
      const len = { DAILY: 1, WEEKLY: 7, MONTHLY: 30 }[period];
      const subStatus: SubscriptionStatus = d % 7 === 3 ? 'GRACE' : d % 11 === 5 ? 'EXPIRED' : 'ACTIVE';
      const startsAt = daysAgo(subStatus === 'EXPIRED' ? len + 3 : Math.random() * len);
      await prisma.subscription.create({
        data: {
          driverId: id, planId: plan.id, status: subStatus, startsAt, endsAt: new Date(startsAt.getTime() + len * 86_400_000),
          upiApp: rand(['GPay', 'PhonePe', 'Paytm']),
          payments: {
            create: [
              { amount: plan.price, status: 'PAID', providerRef: `demo_upi_${d}_1`, createdAt: startsAt },
              ...(subStatus === 'GRACE' ? [{ amount: plan.price, status: 'FAILED' as const, providerRef: `demo_upi_${d}_2` }] : []),
            ],
          },
        },
      });
    }
  }

  // Spread demo trips over the passengers; finished ones get an approved driver of the same vehicle.
  const moved = await prisma.$executeRaw`
    UPDATE "Trip" t SET "passengerId" = (${passengers}::text[])[1 + floor(random() * ${passengers.length})::int]
    WHERE t.id LIKE 'demo\_%'`;
  await prisma.$executeRaw`
    UPDATE "Trip" t SET
      "driverId" = (SELECT dr.id FROM "Driver" dr WHERE dr.id LIKE 'demo\_%' AND dr.status = 'APPROVED'
                    AND dr."vehicleKind" = t."vehicleKind" ORDER BY random() LIMIT 1),
      "assignedAt" = t."createdAt" + interval '1 minute',
      "rating" = CASE WHEN t.status <> 'CANCELLED' AND random() < 0.6 THEN 3 + floor(random() * 3)::int END
    WHERE t.id LIKE 'demo\_%' AND t.status IN ('COMPLETED', 'DELIVERED', 'CANCELLED')`;
  await prisma.$executeRaw`
    UPDATE "Driver" dr SET "ridesCount" = (SELECT count(*) FROM "Trip" t WHERE t."driverId" = dr.id AND t.status IN ('COMPLETED', 'DELIVERED'))
    WHERE dr.id LIKE 'demo\_%'`;

  // Support tickets, some linked to a trip.
  const trips = await prisma.trip.findMany({ where: { id: { startsWith: 'demo_' }, status: { in: ['COMPLETED', 'DELIVERED'] } }, select: { id: true, passengerId: true, createdAt: true }, take: 12 });
  for (let i = 0; i < 12; i++) {
    const [topic, description] = TOPICS[i % TOPICS.length];
    const trip = trips[i];
    await prisma.supportTicket.create({
      data: {
        id: `demo_t${i}`, userId: trip?.passengerId ?? rand(passengers), tripId: i % 3 === 2 ? null : trip?.id,
        topic, description, status: i < 5 ? 'OPEN' : i < 8 ? 'IN_PROGRESS' : 'RESOLVED', createdAt: trip?.createdAt ?? daysAgo(i),
      },
    });
  }

  console.log(`Added ${passengers.length} passengers, ${d} drivers (with KYC, subscriptions, payments), 12 tickets; spread ${moved} demo trips`);
}

await main();
await prisma.$disconnect();
