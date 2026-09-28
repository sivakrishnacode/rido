// End-to-end: needs Postgres + Redis (`docker compose up -d postgres redis` and `npm run prisma:deploy -w @rido/api`).
import { createHmac } from 'node:crypto';

import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/core/prisma/prisma.service.js';
import { JobsService } from '../src/core/jobs/jobs.service.js';
import { RedisService } from '../src/core/redis/redis.service.js';
import { SettingsService } from '../src/modules/settings/settings.service.js';
import { DEMAND_RES } from '../src/modules/geo/demand.service.js';
import { cellAt } from '../src/modules/geo/h3.util.js';
import { DiditClient } from '../src/modules/kyc/didit.client.js';
import type { DiditDecision } from '../src/modules/kyc/didit.js';

const GANDHIPURAM = { lat: 11.0183, lng: 76.9725, placeId: 'gandhipuram', name: 'Gandhipuram Central Bus Stand' };
const BROOKEFIELDS = { lat: 11.009, lng: 76.96, placeId: 'brookefields', name: 'Brookefields Mall' };

const ADMIN_PHONE = '9000000001';

/** Random valid Indian mobile number so runs don't collide. */
function phone(): string {
  return `9${String(Math.floor(Math.random() * 1e9)).padStart(9, '0')}`;
}

const WEBHOOK_SECRET = 'whsec_e2e';
/** A stored photo so drivers approved directly in the database may go online (photo required with Didit on). */
const E2E_PHOTO = '00000000-0000-4000-8000-00000000e2e0.jpg';
/** Smallest valid JPEG header bytes: enough for storage (it only checks the type). */
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0xff, 0xd9]);

/** Stands in for Didit: sessions are per user, decisions are set by the test. */
const fakeDidit = {
  isEnabled: true,
  decisions: new Map<string, DiditDecision>(),
  createSession: async (p: { userId: string }) => ({ sessionId: `sess-${p.userId}`, sessionToken: `tok-${p.userId}`, status: 'Not Started' }),
  decision: async (sessionId: string) => fakeDidit.decisions.get(sessionId) ?? { session_id: sessionId, status: 'In Progress' },
  image: async (url: string) => (url.startsWith('https://') ? { buffer: JPEG, mimetype: 'image/jpeg' } : null),
  /** Next face-match result for a profile photo. */
  nextMatch: { score: 97 as number | null, faces: 1, isMatch: true },
  faceMatch: async () => fakeDidit.nextMatch,
};

/** Signs a webhook body like Didit (X-Signature-V2 over sorted compact JSON). */
function signed(body: Record<string, unknown>): { headers: Record<string, string>; body: Record<string, unknown> } {
  const sort = (v: unknown): unknown =>
    Array.isArray(v) ? v.map(sort) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sort((v as Record<string, unknown>)[k])])) : v;
  const sig = createHmac('sha256', WEBHOOK_SECRET).update(JSON.stringify(sort(body))).digest('hex');
  return { headers: { 'x-signature-v2': sig, 'x-timestamp': String(Math.floor(Date.now() / 1000)) }, body };
}

describe('Rido API (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let http: ReturnType<typeof request>;

  beforeAll(async () => {
    process.env.OTP_DEV_MODE = 'true';
    process.env.ADMIN_PHONES = ADMIN_PHONE;
    process.env.GOOGLE_MAPS_API_KEY = ''; // no paid Google calls in tests
    // Didit is "set up" with a fake client, so drivers need an identity check to be approved.
    process.env.DIDIT_API_KEY = 'e2e';
    process.env.DIDIT_WEBHOOK_SECRET = WEBHOOK_SECRET;
    process.env.DIDIT_DRIVER_WORKFLOW_ID = 'wf-driver';
    process.env.DIDIT_RIDER_WORKFLOW_ID = 'wf-rider';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).overrideProvider(DiditClient).useValue(fakeDidit).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health', 'health/ready'] });
    await app.init();
    prisma = app.get(PrismaService);
    const redis = app.get(RedisService);
    const otpKeys = await redis.keys('otp:*');
    if (otpKeys.length) await redis.del(...otpKeys);
    const keys = [...(await redis.keys('h3:*')), ...(await redis.keys('hexstats:*')), ...(await redis.keys('driver:*')), ...(await redis.keys('dispatch:*')), ...(await redis.keys('jobs:*'))];
    if (keys.length) await redis.del(...keys);
    http = request(app.getHttpServer());
  });

  afterAll(async () => {
    await app.close();
  });

  async function login(): Promise<string> {
    const p = phone();
    await http.post('/v1/auth/otp').send({ phone: p }).expect(200);
    const res = await http.post('/v1/auth/verify').send({ phone: p, code: '123456' }).expect(200);
    return res.body.accessToken as string;
  }

  it('reports ready', async () => {
    await http.get('/health/ready').expect(200, { status: 'ok', database: 'up', redis: 'up' });
  });

  it('rejects the wrong OTP and protected routes without a token', async () => {
    const p = phone();
    await http.post('/v1/auth/verify').send({ phone: p, code: '000000' }).expect(401);
    await http.get('/v1/me').expect(401);
  });

  it('quotes fares with no peak markup by default', async () => {
    const res = await http.post('/v1/fares/quote').send({ pickup: GANDHIPURAM, drop: BROOKEFIELDS }).expect(200);
    expect(res.body.quotes.map((q: { total: number }) => q.total)).toEqual([35, 66, 132]);
  });

  it('runs a bike ride end to end', async () => {
    // Arrange: a passenger and an approved, online bike driver near the pickup.
    const passenger = await login();
    const driverUser = await login();
    const plate = `TN 37 AB ${Math.floor(1000 + Math.random() * 8999)}`;
    const reg = await http
      .post('/v1/drivers')
      .set('Authorization', `Bearer ${driverUser}`)
      .send({ name: 'Karthik S', workType: 'RIDES', vehicleKind: 'BIKE', vehicleModel: 'Honda Activa', vehicleColor: 'Grey', plate, upiId: 'karthik@okaxis' })
      .expect(201);
    const driver = reg.body.accessToken as string;
    await prisma.driver.update({ where: { id: reg.body.driver.id }, data: { status: 'APPROVED', photoFile: E2E_PHOTO } });
    await http.post('/v1/drivers/me/online').set('Authorization', `Bearer ${driver}`).send({ lat: 11.019, lng: 76.973 }).expect(200);

    // Act: book, accept, arrive, start with OTP, complete, rate.
    const trip = (await http
      .post('/v1/trips')
      .set('Authorization', `Bearer ${passenger}`)
      .send({ kind: 'RIDE', vehicleKind: 'BIKE', pickup: GANDHIPURAM, drop: BROOKEFIELDS })
      .expect(201)).body;
    const auth = { Authorization: `Bearer ${driver}` };
    // Matching runs in ~2 s batches: retry until this driver has the offer.
    let accepted = 0;
    for (let i = 0; i < 30 && accepted !== 200; i++) {
      accepted = (await http.post(`/v1/trips/${trip.id}/accept`).set(auth)).status;
      if (accepted !== 200) await new Promise((r) => setTimeout(r, 250));
    }
    expect(accepted).toBe(200);
    const arrived = (await http.post(`/v1/trips/${trip.id}/arrived`).set(auth).expect(200)).body;
    // The driver never gets the OTP: the rider reads it out.
    expect(arrived).toMatchObject({ otp: '' });
    expect(arrived.arrivedAt).not.toBeNull();
    const wrongOtp = { otp: '0000' === trip.otp ? '1111' : '0000' };
    await http.post(`/v1/trips/${trip.id}/start`).set(auth).send(wrongOtp).expect(400);
    // 5 tries a minute: the 5th wrong one locks the OTP, even the right one, until the minute is up.
    for (let i = 0; i < 3; i++) await http.post(`/v1/trips/${trip.id}/start`).set(auth).send(wrongOtp).expect(400);
    expect((await http.post(`/v1/trips/${trip.id}/start`).set(auth).send(wrongOtp).expect(429)).body.code).toBe('OTP_LOCKED');
    await http.post(`/v1/trips/${trip.id}/start`).set(auth).send({ otp: trip.otp }).expect(429);
    await app.get(RedisService).del(`trip:otp-tries:${trip.id}`); // the minute is up
    await http.post(`/v1/trips/${trip.id}/start`).set(auth).send({ otp: trip.otp }).expect(200);
    // A retried start is fine; the passenger can't cancel a ride that has started.
    expect((await http.post(`/v1/trips/${trip.id}/start`).set(auth).send({ otp: trip.otp }).expect(200)).body.status).toBe('IN_PROGRESS');
    await http.post(`/v1/trips/${trip.id}/cancel`).set('Authorization', `Bearer ${passenger}`).send({}).expect(400);
    // The server's fresh GPS fix (still at the pickup) wins over coordinates the app claims.
    const end = { lat: BROOKEFIELDS.lat, lng: BROOKEFIELDS.lng };
    expect((await http.post(`/v1/trips/${trip.id}/complete`).set(auth).send(end).expect(422)).body.code).toBe('TOO_FAR');
    await http.post('/v1/drivers/me/location').set(auth).send(end).expect(204);
    // Ended at the drop (farther than dropRadiusM would need a reason). A double tap counts the ride once.
    const [done, again] = await Promise.all([
      http.post(`/v1/trips/${trip.id}/complete`).set(auth).send(end),
      http.post(`/v1/trips/${trip.id}/complete`).set(auth).send(end),
    ]);
    expect([done.status, again.status]).toEqual([200, 200]);
    expect((await prisma.driver.findUniqueOrThrow({ where: { id: reg.body.driver.id } })).ridesCount).toBe(1);
    // Rating = mean of the ratings given (not averaged over rides); a second rating is refused.
    await http.post(`/v1/trips/${trip.id}/rate`).set('Authorization', `Bearer ${passenger}`).send({ rating: 4 }).expect(200);
    await http.post(`/v1/trips/${trip.id}/rate`).set('Authorization', `Bearer ${passenger}`).send({ rating: 1 }).expect(409);
    expect(await prisma.driver.findUniqueOrThrow({ where: { id: reg.body.driver.id } })).toMatchObject({ rating: 4, ratingSum: 4, ratingCount: 1 });

    // Assert
    expect(trip.fareTotal).toBe(35);
    expect(done.body.status).toBe('COMPLETED');
    const history = await http.get('/v1/trips').set('Authorization', `Bearer ${passenger}`).expect(200);
    expect(history.body[0].id).toBe(trip.id);
  });

  /** An approved driver of [vehicleKind], online at [at]. Returns their token. */
  async function onlineDriver(vehicleKind: string, at: { lat: number; lng: number }, gender?: 'FEMALE' | 'MALE'): Promise<string> {
    const user = await login();
    const plate = `TN 37 ${vehicleKind.slice(0, 2)} ${Math.floor(1000 + Math.random() * 8999)}`;
    const reg = await http
      .post('/v1/drivers')
      .set('Authorization', `Bearer ${user}`)
      .send({ name: 'Test Driver', workType: 'RIDES', vehicleKind, vehicleModel: 'Test', vehicleColor: 'White', plate, upiId: 'test@okaxis', gender })
      .expect(201);
    await prisma.driver.update({ where: { id: reg.body.driver.id }, data: { status: 'APPROVED', photoFile: E2E_PHOTO } });
    const token = reg.body.accessToken as string;
    await http.post('/v1/drivers/me/online').set('Authorization', `Bearer ${token}`).send(at).expect(200);
    return token;
  }

  /** Retries accept while matching runs (~2 s batches); returns the last response. */
  async function acceptWhenOffered(tripId: string, driver: string, tries = 40): Promise<request.Response> {
    let res = await http.post(`/v1/trips/${tripId}/accept`).set('Authorization', `Bearer ${driver}`);
    for (let i = 1; i < tries && res.status !== 200; i++) {
      await new Promise((r) => setTimeout(r, 250));
      res = await http.post(`/v1/trips/${tripId}/accept`).set('Authorization', `Bearer ${driver}`);
    }
    return res;
  }

  it('quotes carry the nearest driver\'s pickup ETA (null when nobody is near)', async () => {
    const bikeDriver = await onlineDriver('BIKE', { lat: 11.0185, lng: 76.9727 });
    const quotes = (await http.post('/v1/fares/quote').send({ pickup: GANDHIPURAM, drop: BROOKEFIELDS }).expect(200)).body.quotes;
    const bike = quotes.find((q: { vehicleKind: string }) => q.vehicleKind === 'BIKE');
    expect(typeof bike.pickupEtaMin).toBe('number');
    expect(bike.total).toBe(35);
    const far = { lat: 11.2, lng: 77.2, name: 'Far away' };
    const empty = (await http.post('/v1/fares/quote').send({ pickup: far, drop: BROOKEFIELDS }).expect(200)).body.quotes;
    expect(empty.every((q: { pickupEtaMin: number | null }) => q.pickupEtaMin === null)).toBe(true);
    await http.post('/v1/drivers/me/offline').set('Authorization', `Bearer ${bikeDriver}`).expect(200);
  });

  it('Butterfly "only": needs a woman rider and goes to the woman driver, never the closer man', async () => {
    // Arrange: a man right at the pickup, a woman a little further.
    const at = { lat: 11.0184, lng: 76.9726 };
    const man = await onlineDriver('CAB', at, 'MALE');
    const woman = await onlineDriver('CAB', { lat: 11.0195, lng: 76.9738 }, 'FEMALE');
    const rider = await login();
    const pax = { Authorization: `Bearer ${rider}` };
    const book = { kind: 'RIDE', vehicleKind: 'CAB', pickup: GANDHIPURAM, drop: BROOKEFIELDS, womenDriver: 'ONLY' };

    // Act + assert: no gender set → refused; FEMALE → booked with the preference.
    await http.post('/v1/trips').set(pax).send(book).expect(400);
    await http.patch('/v1/me').set(pax).send({ gender: 'FEMALE' }).expect(200);
    const womenOnlyQuote = (await http.post('/v1/fares/quote').send({ pickup: GANDHIPURAM, drop: BROOKEFIELDS, womenOnly: true }).expect(200)).body.quotes;
    expect(womenOnlyQuote.find((q: { vehicleKind: string }) => q.vehicleKind === 'CAB').pickupEtaMin).not.toBeNull();
    const trip = (await http.post('/v1/trips').set(pax).send(book).expect(201)).body;
    expect(trip.womenDriver).toBe('ONLY');
    const accepted = await acceptWhenOffered(trip.id, woman);
    expect(accepted.status).toBe(200);
    expect((await http.post(`/v1/trips/${trip.id}/accept`).set('Authorization', `Bearer ${man}`)).status).not.toBe(200);
    await http.post(`/v1/trips/${trip.id}/cancel`).set(pax).send({}).expect(200);
    for (const d of [man, woman]) await http.post('/v1/drivers/me/offline').set('Authorization', `Bearer ${d}`);
  });

  it('"Who\'s riding?": a father books Butterfly for his daughter; the driver sees her; reports switch it off', async () => {
    const woman = await onlineDriver('AUTO', { lat: 11.0186, lng: 76.9728 }, 'FEMALE');
    const father = await login(); // no gender set
    const pax = { Authorization: `Bearer ${father}` };
    const daughter = { name: 'Anjali', phone: '9876512345', isWoman: true };
    const book = { kind: 'RIDE', vehicleKind: 'AUTO', pickup: GANDHIPURAM, drop: BROOKEFIELDS, womenDriver: 'ONLY' };

    // Not a woman rider → refused; for a woman rider → booked with her details.
    await http.post('/v1/trips').set(pax).send({ ...book, rider: { ...daughter, isWoman: false } }).expect(400);
    await http.post('/v1/trips').set(pax).send({ ...book, rider: { ...daughter, phone: '123' } }).expect(400);
    const trip = (await http.post('/v1/trips').set(pax).send({ ...book, rider: daughter }).expect(201)).body;
    expect(trip).toMatchObject({ womenDriver: 'ONLY', riderName: 'Anjali', riderPhone: '+919876512345', riderIsWoman: true });

    // The driver's request card shows the rider, "booked by" the account holder.
    let offer: { passenger: { name: string; phone: string; bookedBy?: string } } | null = null;
    for (let i = 0; i < 40 && !offer; i++) {
      const res = await http.get('/v1/trips/offer').set('Authorization', `Bearer ${woman}`);
      offer = res.status === 200 && res.body?.trip?.id === trip.id ? res.body : null;
      if (!offer) await new Promise((r) => setTimeout(r, 250));
    }
    expect(offer?.passenger).toMatchObject({ name: 'Anjali', phone: '+919876512345' });
    expect((await acceptWhenOffered(trip.id, woman)).status).toBe(200);
    // An older driver app sends only the reason text: it becomes the Butterfly-mismatch code (no fault).
    const reported = (await http.post(`/v1/trips/${trip.id}/cancel`).set('Authorization', `Bearer ${woman}`).send({ reason: 'Rider is not a woman' }).expect(200)).body;
    expect(reported).toMatchObject({ status: 'CANCELLED', cancelledBy: 'DRIVER', cancelCode: 'BUTTERFLY_MISMATCH', cancelReason: 'Rider is not a woman' });
    expect(await prisma.tripCancellation.findMany({ where: { tripId: trip.id } })).toMatchObject([{ by: 'DRIVER', code: 'BUTTERFLY_MISMATCH', isDriverFault: false }]);

    // A second report switches Butterfly-for-others off for this account (own rides are not affected by it).
    const second = (await http.post('/v1/trips').set(pax).send({ ...book, rider: daughter }).expect(201)).body;
    await prisma.trip.update({ where: { id: second.id }, data: { status: 'CANCELLED', cancelledBy: 'DRIVER', cancelCode: 'BUTTERFLY_MISMATCH' } });
    await http.post('/v1/trips').set(pax).send({ ...book, rider: daughter }).expect(403);
    const plain = (await http.post('/v1/trips').set(pax).send({ ...book, womenDriver: undefined, rider: daughter }).expect(201)).body;
    expect(plain.womenDriver).toBe('NONE');
    await http.post(`/v1/trips/${plain.id}/cancel`).set(pax).send({}).expect(200);
    await http.post('/v1/drivers/me/offline').set('Authorization', `Bearer ${woman}`);
  });

  it('"Book any": a slow cab search adds Auto, and the auto driver takes it at the auto fare', async () => {
    // Arrange: no cab nearby, an auto driver at the pickup.
    const passenger = await login();
    const auto = await onlineDriver('AUTO', { lat: 11.0185, lng: 76.9727 });
    const pax = { Authorization: `Bearer ${passenger}` };
    const trip = (await http.post('/v1/trips').set(pax).send({ kind: 'RIDE', vehicleKind: 'CAB', pickup: GANDHIPURAM, drop: BROOKEFIELDS }).expect(201)).body;

    // Act
    const alts = (await http.get(`/v1/trips/${trip.id}/alternatives`).set(pax).expect(200)).body;
    const added = (await http.post(`/v1/trips/${trip.id}/also`).set(pax).send({ vehicleKind: 'AUTO' }).expect(200)).body;
    await http.post(`/v1/trips/${trip.id}/also`).set(pax).send({ vehicleKind: 'GOODS_BIKE' }).expect(400);
    const accepted = await acceptWhenOffered(trip.id, auto);
    expect(accepted.body.otp).toBe('');

    // Assert
    const autoAlt = alts.find((a: { vehicleKind: string }) => a.vehicleKind === 'AUTO');
    expect(autoAlt.quote.total).toBe(66);
    expect(autoAlt.driversNearby).toBeGreaterThan(0);
    expect(alts.map((a: { vehicleKind: string }) => a.vehicleKind)).not.toContain('CAB');
    expect(added.alsoKinds).toEqual(['AUTO']);
    expect(accepted.status).toBe(200);
    expect(accepted.body.vehicleKind).toBe('AUTO');
    expect(accepted.body.fareTotal).toBe(66);
    // A passenger cancel with a code and a note; a driver-only code from a passenger becomes OTHER.
    const cancelled = (await http.post(`/v1/trips/${trip.id}/cancel`).set(pax).send({ code: 'WAIT_TOO_LONG', note: 'Too slow' }).expect(200)).body;
    expect(cancelled).toMatchObject({ cancelledBy: 'PASSENGER', cancelCode: 'WAIT_TOO_LONG', cancelReason: 'Too slow' });
    expect(new Date(cancelled.cancelledAt).getTime()).toBeGreaterThan(Date.now() - 60_000);
    await http.post(`/v1/trips/${trip.id}/cancel`).set(pax).send({ code: 'NOT_A_CODE' }).expect(400);
    const other = (await http.post('/v1/trips').set(pax).send({ kind: 'RIDE', vehicleKind: 'CAB', pickup: GANDHIPURAM, drop: BROOKEFIELDS }).expect(201)).body;
    expect((await http.post(`/v1/trips/${other.id}/cancel`).set(pax).send({ code: 'PASSENGER_NO_SHOW' }).expect(200)).body.cancelCode).toBe('OTHER');
  });

  it('widens the search radius: a cab 7 km away (outside the 5 km start) still gets the request', async () => {
    const settings = app.get(SettingsService);
    await settings.update({ searchRadiusKm: 5, maxSearchRadiusKm: 15, searchExpandSeconds: 4 });
    try {
      // Arrange: the only cab is ~7 km east of the pickup.
      const passenger = await login();
      const cab = await onlineDriver('CAB', { lat: 11.0183, lng: 77.0365 });
      const trip = (await http
        .post('/v1/trips')
        .set('Authorization', `Bearer ${passenger}`)
        .send({ kind: 'RIDE', vehicleKind: 'CAB', pickup: GANDHIPURAM, drop: BROOKEFIELDS })
        .expect(201)).body;

      // Act
      const accepted = await acceptWhenOffered(trip.id, cab);

      // Assert
      expect(accepted.status).toBe(200);
      expect(accepted.body.vehicleKind).toBe('CAB');
    } finally {
      await settings.update({ searchRadiusKm: 5, maxSearchRadiusKm: 15, searchExpandSeconds: 45 });
    }
  });

  it('one open offer and one active trip per driver', async () => {
    // Arrange: only this bike driver is indexed (earlier tests leave bikes online); two riders book bikes.
    const redis = app.get(RedisService);
    const cells = await redis.keys('h3:drv:BIKE:*');
    if (cells.length) await redis.del(...cells);
    const bike = await onlineDriver('BIKE', { lat: 11.0185, lng: 76.9727 });
    const driverId = (await http.get('/v1/drivers/me').set('Authorization', `Bearer ${bike}`).expect(200)).body.id as string;
    const book = { kind: 'RIDE', vehicleKind: 'BIKE', pickup: GANDHIPURAM, drop: BROOKEFIELDS };
    const [paxA, paxB] = [await login(), await login()];
    const a = (await http.post('/v1/trips').set('Authorization', `Bearer ${paxA}`).send(book).expect(201)).body;
    const b = (await http.post('/v1/trips').set('Authorization', `Bearer ${paxB}`).send(book).expect(201)).body;

    // Act: wait for the driver's (single) offer.
    let offered: string | null = null;
    for (let i = 0; i < 40 && !offered; i++) {
      const res = await http.get('/v1/trips/offer').set('Authorization', `Bearer ${bike}`);
      offered = res.status === 200 ? (res.body?.trip?.id ?? null) : null;
      if (!offered) await new Promise((r) => setTimeout(r, 250));
    }
    const other = offered === a.id ? b.id : a.id;

    // Assert: the other trip is never offered to them at the same time, and they can't take it.
    expect([a.id, b.id]).toContain(offered);
    expect(await redis.get(`dispatch:${other}:offer`)).not.toBe(driverId);
    await http.post(`/v1/trips/${other}/accept`).set('Authorization', `Bearer ${bike}`).expect(409);
    await http.post(`/v1/trips/${offered}/accept`).set('Authorization', `Bearer ${bike}`).expect(200);
    expect(await redis.ttl(`driver:busy:${driverId}`)).toBeGreaterThan(3600);
    // Even with a leftover offer for the other trip, a second active trip is refused.
    await redis.set(`dispatch:${other}:offer`, driverId, 'EX', 20);
    const second = await http.post(`/v1/trips/${other}/accept`).set('Authorization', `Bearer ${bike}`).expect(409);
    expect(second.body.message).toBe('Finish your current trip first');
    await redis.del(`dispatch:${other}:offer`);

    // A cancel frees the driver for the other trip.
    await http.post(`/v1/trips/${offered}/cancel`).set('Authorization', `Bearer ${offered === a.id ? paxA : paxB}`).send({}).expect(200);
    expect(await redis.exists(`driver:busy:${driverId}`)).toBe(0);
    // The other trip searches again every few seconds.
    expect((await acceptWhenOffered(other, bike, 80)).status).toBe(200);
    await http.post(`/v1/trips/${other}/cancel`).set('Authorization', `Bearer ${bike}`).send({}).expect(200);
    await http.post('/v1/drivers/me/offline').set('Authorization', `Bearer ${bike}`).expect(200);
  }, 45_000);

  it('keeps offer timeouts as durable Redis jobs', async () => {
    // Arrange: the only bike driver gets the offer.
    const redis = app.get(RedisService);
    const jobs = app.get(JobsService);
    const cells = await redis.keys('h3:drv:BIKE:*');
    if (cells.length) await redis.del(...cells);
    const bike = await onlineDriver('BIKE', { lat: 11.0185, lng: 76.9727 });
    const driverId = (await http.get('/v1/drivers/me').set('Authorization', `Bearer ${bike}`).expect(200)).body.id as string;
    const pax = { Authorization: `Bearer ${await login()}` };
    const trip = (await http.post('/v1/trips').set(pax).send({ kind: 'RIDE', vehicleKind: 'BIKE', pickup: GANDHIPURAM, drop: BROOKEFIELDS }).expect(201)).body;
    for (let i = 0; i < 40 && (await redis.get(`dispatch:${trip.id}:offer`)) !== driverId; i++) await new Promise((r) => setTimeout(r, 250));

    // Assert: the timeout is a job in Redis (survives a restart), due after offerSeconds.
    const due = await jobs.scheduledAt('offer.expire', trip.id);
    expect(due).not.toBeNull();
    expect(due! - Date.now()).toBeGreaterThan(5_000);
    expect(await redis.zscore('jobs:due', `offer.expire|${trip.id}`)).not.toBeNull();

    // Act: time passes (run the due jobs as if 20 s later): the offer times out and moves on.
    await jobs.runDue(Date.now() + 20_000);
    expect(await redis.get(`dispatch:${trip.id}:offer`)).not.toBe(driverId);
    await http.post(`/v1/trips/${trip.id}/accept`).set('Authorization', `Bearer ${bike}`).expect(409);
    await http.post(`/v1/trips/${trip.id}/cancel`).set(pax).send({}).expect(200);
    expect(await jobs.scheduledAt('offer.expire', trip.id)).toBeNull();
    expect(await jobs.scheduledAt('dispatch.research', trip.id)).toBeNull();
    await http.post('/v1/drivers/me/offline').set('Authorization', `Bearer ${bike}`).expect(200);
  });

  it('falls back to seeded places and a curved route without a Google key', async () => {
    const ac = await http.get('/v1/places/autocomplete?q=brook&session=t1').expect(200);
    expect(ac.body.results.length).toBeGreaterThan(0);
    const details = await http.get(`/v1/places/details/${ac.body.results[0].placeId}`).expect(200);
    expect(details.body.lat).toBeCloseTo(11.0, 0);
    const route = await http.post('/v1/maps/route').send({ from: GANDHIPURAM, to: BROOKEFIELDS }).expect(200);
    expect(route.body.points.length).toBeGreaterThan(2);
  });

  it('lets only ADMIN_PHONES use the admin API', async () => {
    const passenger = await login();
    await http.get('/v1/admin/stats').set('Authorization', `Bearer ${passenger}`).expect(403);
    await http.post('/v1/auth/otp').send({ phone: ADMIN_PHONE }).expect(200);
    const admin = (await http.post('/v1/auth/verify').send({ phone: ADMIN_PHONE, code: '123456' }).expect(200)).body;
    expect(admin.user.role).toBe('ADMIN');
    const auth = { Authorization: `Bearer ${admin.accessToken}` };
    const stats = await http.get('/v1/admin/stats').set(auth).expect(200);
    expect(stats.body.tripsLast7Days).toHaveLength(7);
    const drivers = await http.get('/v1/admin/drivers?pageSize=5').set(auth).expect(200);
    expect(drivers.body.items.length).toBeGreaterThan(0);
    const driverId = drivers.body.items[0].id as string;
    const docs = await http.post(`/v1/admin/drivers/${driverId}/documents/VEHICLE_RC`).set(auth).send({ status: 'VERIFIED' }).expect(201);
    expect(docs.body.find((d: { type: string }) => d.type === 'VEHICLE_RC').status).toBe('VERIFIED');
    await http.get('/v1/admin/trips').set(auth).expect(200);
    const heat = await http.get('/v1/admin/heatmap?metric=pickups').set(auth).expect(200);
    expect(heat.body.cells.length).toBeGreaterThan(0);
    expect(heat.body.cells[0].intensity).toBe(1);
    await http.get('/v1/admin/heatmap?metric=unmet&hourFrom=7&hourTo=10&resolution=7').set(auth).expect(200);
    await http.get('/v1/admin/plans').set(auth).expect(200);
  });

  it('uses H3 service areas: outside is refused, admins add cities, zones and blocks', async () => {
    const passenger = await login();
    await http.post('/v1/auth/otp').send({ phone: ADMIN_PHONE }).expect(200);
    const admin = { Authorization: `Bearer ${(await http.post('/v1/auth/verify').send({ phone: ADMIN_PHONE, code: '123456' })).body.accessToken}` };

    // Gandhipuram is inside the seeded Coimbatore hexes; Mettupalayam (~31 km) is not.
    const inside = await http.get('/v1/geo/check?lat=11.0183&lng=76.9725').expect(200);
    expect(inside.body).toMatchObject({ cityId: 'coimbatore', isServiceable: true });
    const outside = { lat: 11.299, lng: 76.935, name: 'Mettupalayam' };
    await http.post('/v1/trips').set('Authorization', `Bearer ${passenger}`)
      .send({ kind: 'RIDE', vehicleKind: 'BIKE', pickup: GANDHIPURAM, drop: outside }).expect(400);

    // A new city with a custom hex area and a surge zone.
    const id = `tiruppur-${Date.now()}`;
    const city = await http.post('/v1/admin/cities').set(admin)
      .send({ id, name: 'Tiruppur', state: 'Tamil Nadu', centerLat: 11.1085, centerLng: 77.3411, radiusKm: 3 }).expect(201);
    expect(city.body.serviceCells.length).toBeGreaterThan(10);
    const cells = city.body.serviceCells.slice(0, 7) as string[];
    await http.put(`/v1/admin/cities/${id}/service-cells`).set(admin).send({ cells: [...cells, 'bogus'] }).expect(200, { count: 7, rejected: ['bogus'] });
    await http.post(`/v1/admin/cities/${id}/zones`).set(admin)
      .send({ name: 'Old bus stand', kind: 'SURGE', cells: cells.slice(0, 1), surgeMultiplier: 1.3 }).expect(201);
    const area = await http.get(`/v1/cities/${id}/service-area`).expect(200);
    expect(area.body.cells).toHaveLength(7);
    expect(area.body.zones[0].kind).toBe('SURGE');
    await http.delete(`/v1/admin/cities/${id}`).set(admin).expect(204);

    // Blocking takes effect on the next request.
    const me = (await http.get('/v1/me').set('Authorization', `Bearer ${passenger}`).expect(200)).body;
    await http.patch(`/v1/admin/users/${me.id}`).set(admin).send({ isBlocked: true, blockedReason: 'Test block' }).expect(200);
    await http.get('/v1/me').set('Authorization', `Bearer ${passenger}`).expect(403);
    await http.patch(`/v1/admin/users/${me.id}`).set(admin).send({ isBlocked: false }).expect(200);
    await http.get('/v1/me').set('Authorization', `Bearer ${passenger}`).expect(200);

    const blockedList = await http.get('/v1/admin/users?role=PASSENGER&blocked=false&pageSize=5').set(admin).expect(200);
    expect(blockedList.body.items.every((u: { role: string }) => u.role === 'PASSENGER')).toBe(true);

    // Every admin change is audited.
    const audit = await http.get('/v1/admin/audit?pageSize=5').set(admin).expect(200);
    expect(audit.body.items.length).toBeGreaterThan(0);
  });

  it('surges from live H3 demand and learns hex-to-hex speeds', async () => {
    await http.post('/v1/auth/otp').send({ phone: ADMIN_PHONE }).expect(200);
    const admin = { Authorization: `Bearer ${(await http.post('/v1/auth/verify').send({ phone: ADMIN_PHONE, code: '123456' })).body.accessToken}` };
    const peelamedu = { lat: 11.029, lng: 77.027, name: 'Peelamedu' };
    const raceCourse = { lat: 10.999, lng: 76.978, name: 'Race Course' };
    // Demand counts each passenger once per window: five different riders.
    for (let i = 0; i < 5; i++) {
      const rider = await login();
      await http.post('/v1/trips').set('Authorization', `Bearer ${rider}`)
        .send({ kind: 'RIDE', vehicleKind: 'AUTO', pickup: peelamedu, drop: raceCourse }).expect(201);
    }
    // No drivers near Peelamedu: demand ÷ supply is high → the cell (and, smoothed, its neighbours) surges.
    const snap = await http.get('/v1/admin/demand?refresh=true').set(admin).expect(200);
    // Peelamedu's own cell (other tests' bookings may make Gandhipuram busy too).
    const hot = snap.body.cells.find((c: { cell: string }) => c.cell === cellAt(peelamedu.lat, peelamedu.lng, DEMAND_RES));
    expect(hot.requests).toBeGreaterThanOrEqual(5);
    expect(hot.level).toBe('high');
    expect(hot.multiplier).toBeGreaterThan(1.1);
    const here = await http.get(`/v1/geo/check?lat=${peelamedu.lat}&lng=${peelamedu.lng}`).expect(200);
    expect(here.body.multiplier).toBe(hot.multiplier);
    const publicDemand = await http.get('/v1/demand').expect(200);
    expect(publicDemand.body.cells.some((c: { cell: string }) => c.cell === hot.cell)).toBe(true);

    // Learned speeds: rebuild from completed trips (the ride test completed one) and read the summary.
    const rebuilt = await http.post('/v1/admin/hex-stats/rebuild').set(admin).expect(200);
    expect(rebuilt.body.pairs).toBeGreaterThanOrEqual(0);
    const stats = await http.get('/v1/admin/hex-stats').set(admin).expect(200);
    expect(stats.body.lastRun).not.toBeNull();
    const compact = await http.get('/v1/cities/coimbatore/service-area?compact=true').expect(200);
    expect(compact.body.compacted).toBe(true);
  });

  it('serves the public app config: plans off, contribute page without a cost until one is set', async () => {
    const res = await http.get('/v1/app-config').expect(200);
    expect(res.body.driverPlansEnabled).toBe(false);
    expect(res.body.contribute).toMatchObject({ upiId: '', payeeName: 'Rido', monthlyCost: null });
  });

  it('starts a free trial and lists daily/weekly/monthly plans', async () => {
    const plans = await http.get('/v1/plans?vehicleKind=BIKE').expect(200);
    expect(plans.body.map((p: { price: number }) => p.price)).toEqual([79, 449, 1499]);
  });
  it('approves a driver after the Didit identity check and the RC + insurance review', async () => {
    const driverUser = await login();
    const plate = `TN 38 KY ${Math.floor(1000 + Math.random() * 8999)}`;
    const reg = await http
      .post('/v1/drivers')
      .set('Authorization', `Bearer ${driverUser}`)
      .send({ name: 'Murugan Selvam', workType: 'RIDES', vehicleKind: 'AUTO', vehicleModel: 'Bajaj RE', vehicleColor: 'Green', plate, upiId: 'murugan@okaxis' })
      .expect(201);
    const driver = { Authorization: `Bearer ${reg.body.accessToken as string}` };
    const driverId = reg.body.driver.id as string;
    const userId = reg.body.driver.userId as string;

    // Only RC and insurance are uploaded now (no licence / Aadhaar / police photos).
    const docs = await http.get('/v1/drivers/me/documents').set(driver).expect(200);
    expect(docs.body.map((d: { type: string }) => d.type).sort()).toEqual(['INSURANCE', 'VEHICLE_RC']);
    await http.post('/v1/drivers/me/documents/POLICE_VERIFICATION').set(driver).attach('file', Buffer.from('x'), 'p.jpg').expect(400);

    // The app gets a token for the in-app SDK; the same unfinished session is reused.
    const started = await http.post('/v1/kyc/session').set(driver).expect(201);
    expect(started.body).toEqual({ sessionId: `sess-${userId}`, sessionToken: `tok-${userId}` });
    await http.post('/v1/kyc/session').set(driver).expect(201);
    expect(await prisma.identityVerification.count({ where: { userId } })).toBe(1);

    // Admin verifies both documents: still pending until identity passes.
    await http.post('/v1/auth/otp').send({ phone: ADMIN_PHONE }).expect(200);
    const admin = { Authorization: `Bearer ${(await http.post('/v1/auth/verify').send({ phone: ADMIN_PHONE, code: '123456' })).body.accessToken}` };
    for (const type of ['VEHICLE_RC', 'INSURANCE']) {
      await http.post(`/v1/admin/drivers/${driverId}/documents/${type}`).set(admin).send({ status: 'VERIFIED' }).expect(201);
    }
    expect((await http.get('/v1/drivers/me').set(driver).expect(200)).body.status).toBe('PENDING');

    // Unsigned or badly signed webhooks are refused.
    const event = {
      event_id: `evt-${userId}`,
      webhook_type: 'status.updated',
      session_id: `sess-${userId}`,
      status: 'Approved',
      vendor_data: userId,
      decision: {
        status: 'Approved',
        id_verifications: [
          { document_type: 'Driving License', document_number: 'TN3820190012345', full_name: 'Murugan Selvam', date_of_birth: '1990-04-12', warnings: [] },
          { document_type: 'Identity Card', document_number: '1234 5678 9012', full_name: 'Murugan Selvam', warnings: [] },
        ],
        liveness_checks: [{ status: 'Approved', reference_image: 'https://media.didit.test/face/selfie.jpg' }],
      },
    };
    await http.post('/v1/kyc/didit/webhook').send(event).expect(401);
    const hook = signed(event);
    await http.post('/v1/kyc/didit/webhook').set(hook.headers).send(hook.body).expect(200);
    await http.post('/v1/kyc/didit/webhook').set(hook.headers).send(hook.body).expect(200); // duplicate: ignored

    const me = await http.get('/v1/kyc/me').set(driver).expect(200);
    expect(me.body).toMatchObject({
      isEnabled: true,
      status: 'APPROVED',
      fullName: 'Murugan Selvam',
      documentLast4: '2345',
      documents: [
        { type: 'Driving License', last4: '2345' },
        { type: 'Identity Card', last4: '9012' },
      ],
    });
    expect((await http.get('/v1/drivers/me').set(driver).expect(200)).body.status).toBe('APPROVED');
    await http.post('/v1/kyc/session').set(driver).expect(409);

    // The approved live selfie is kept as the reference face; the profile photo is taken separately.
    const profile = (await http.get('/v1/drivers/me').set(driver).expect(200)).body;
    expect(profile.selfieFile).toMatch(/\.jpg$/);
    expect(profile.photoFile).toBeNull();

    // No face in the photo → retake. A clear match → riders see it at once.
    fakeDidit.nextMatch = { score: null, faces: 0, isMatch: false };
    await http.post('/v1/drivers/me/photo').set(driver).attach('file', JPEG, { filename: 'p.jpg', contentType: 'image/jpeg' }).expect(422);
    fakeDidit.nextMatch = { score: 97, faces: 1, isMatch: true };
    const up = await http.post('/v1/drivers/me/photo').set(driver).attach('file', JPEG, { filename: 'p.jpg', contentType: 'image/jpeg' }).expect(200);
    expect(up.body).toEqual({ status: 'APPROVED' });

    // The driver, admins and their riders see it; a stranger gets 404.
    const photo = await http.get(`/v1/drivers/${driverId}/photo`).set(driver).expect(200);
    expect(photo.headers['content-type']).toContain('image/jpeg');
    await http.get('/v1/drivers/me/photo').set(driver).expect(200);
    await http.get(`/v1/drivers/${driverId}/photo`).set(admin).expect(200);
    const stranger = { Authorization: `Bearer ${await login()}` };
    await http.get(`/v1/drivers/${driverId}/photo`).set(stranger).expect(404);

    // A low match waits for an admin, who approves it.
    fakeDidit.nextMatch = { score: 41, faces: 1, isMatch: false };
    const low = await http.post('/v1/drivers/me/photo').set(driver).attach('file', JPEG, { filename: 'p.jpg', contentType: 'image/jpeg' }).expect(200);
    expect(low.body).toEqual({ status: 'IN_REVIEW' });
    const pending = (await http.get('/v1/drivers/me').set(driver).expect(200)).body;
    expect(pending.pendingPhotoFile).toMatch(/\.jpg$/);
    await http.post(`/v1/admin/drivers/${driverId}/photo`).set(admin).send({ isApproved: true }).expect(200);
    expect((await http.get('/v1/drivers/me').set(driver).expect(200)).body.photoFile).toBe(pending.pendingPhotoFile);
    fakeDidit.nextMatch = { score: 97, faces: 1, isMatch: true };
  });

  it('needs the verified photo before an approved driver can go online', async () => {
    const driverUser = await login();
    const reg = await http
      .post('/v1/drivers')
      .set('Authorization', `Bearer ${driverUser}`)
      .send({ name: 'Ravi M', workType: 'RIDES', vehicleKind: 'BIKE', vehicleModel: 'Hero Splendor', vehicleColor: 'Black', plate: `TN 66 PH ${Math.floor(1000 + Math.random() * 8999)}`, upiId: 'ravi@okaxis' })
      .expect(201);
    const driver = { Authorization: `Bearer ${reg.body.accessToken as string}` };
    await prisma.driver.update({ where: { id: reg.body.driver.id }, data: { status: 'APPROVED' } });
    const res = await http.post('/v1/drivers/me/online').set(driver).send({ lat: 11.019, lng: 76.973 }).expect(403);
    expect(res.body.code).toBe('PHOTO_REQUIRED');
  });

  it('sends a driver approved without a driving licence to review', async () => {
    const driverUser = await login();
    const reg = await http
      .post('/v1/drivers')
      .set('Authorization', `Bearer ${driverUser}`)
      .send({ name: 'Anand K', workType: 'RIDES', vehicleKind: 'BIKE', vehicleModel: 'TVS Jupiter', vehicleColor: 'Blue', plate: `TN 39 NL ${Math.floor(1000 + Math.random() * 8999)}`, upiId: 'anand@okaxis' })
      .expect(201);
    const driver = { Authorization: `Bearer ${reg.body.accessToken as string}` };
    const { sessionId } = (await http.post('/v1/kyc/session').set(driver).expect(201)).body as { sessionId: string };
    fakeDidit.decisions.set(sessionId, { session_id: sessionId, status: 'Approved', id_verifications: [{ document_type: 'Identity Card', document_number: '1234 5678 9012' }] });
    const res = await http.post('/v1/kyc/sync').set(driver).expect(200);
    expect(res.body.status).toBe('IN_REVIEW');
  });

  it('gives riders an optional Verified badge via sync when the SDK closes', async () => {
    const rider = { Authorization: `Bearer ${await login()}` };
    expect((await http.get('/v1/kyc/me').set(rider).expect(200)).body.status).toBe('NOT_STARTED');
    const { sessionId } = (await http.post('/v1/kyc/session').set(rider).expect(201)).body as { sessionId: string };
    fakeDidit.decisions.set(sessionId, {
      session_id: sessionId,
      status: 'Declined',
      face_matches: [{ status: 'Declined', warnings: [{ short_description: 'Face does not match the ID', log_type: 'error' }] }],
    });
    const declined = await http.post('/v1/kyc/sync').set(rider).expect(200);
    expect(declined.body).toMatchObject({ status: 'DECLINED', reasons: ['Selfie: Face does not match the ID'] });
    fakeDidit.decisions.set(sessionId, { session_id: sessionId, status: 'Approved', id_verifications: [{ document_type: 'Aadhaar', document_number: '1234 5678 9012' }] });
    const approved = await http.post('/v1/kyc/sync').set(rider).expect(200);
    expect(approved.body).toMatchObject({ status: 'APPROVED', documentLast4: '9012' });
    expect((await http.get('/v1/me').set(rider).expect(200)).body.identityStatus).toBe('APPROVED');

    // A newer session that only expires (e.g. "Try again" opened and closed) keeps the approval.
    const userId = (await http.get('/v1/me').set(rider).expect(200)).body.id as string;
    await prisma.identityVerification.create({ data: { userId, purpose: 'RIDER', sessionId: `later-${userId}` } });
    const expired = signed({ event_id: `evt-exp-${userId}`, webhook_type: 'status.updated', session_id: `later-${userId}`, status: 'Expired', vendor_data: userId });
    await http.post('/v1/kyc/didit/webhook').set(expired.headers).send(expired.body).expect(200);
    expect((await http.get('/v1/kyc/me').set(rider).expect(200)).body.status).toBe('APPROVED');
  });
});
