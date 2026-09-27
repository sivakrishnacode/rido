// End-to-end: needs Postgres + Redis (`docker compose up -d postgres redis` and `npm run prisma:deploy -w @rido/api`).
import { createHmac } from 'node:crypto';

import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/core/prisma/prisma.service.js';
import { RedisService } from '../src/core/redis/redis.service.js';
import { SettingsService } from '../src/modules/settings/settings.service.js';
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

/** Stands in for Didit: sessions are per user, decisions are set by the test. */
const fakeDidit = {
  isEnabled: true,
  decisions: new Map<string, DiditDecision>(),
  createSession: async (p: { userId: string }) => ({ sessionId: `sess-${p.userId}`, sessionToken: `tok-${p.userId}`, status: 'Not Started' }),
  decision: async (sessionId: string) => fakeDidit.decisions.get(sessionId) ?? { session_id: sessionId, status: 'In Progress' },
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
    const keys = [...(await redis.keys('h3:*')), ...(await redis.keys('hexstats:*')), ...(await redis.keys('driver:*')), ...(await redis.keys('dispatch:*'))];
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

  it('quotes the design fares', async () => {
    const res = await http.post('/v1/fares/quote').send({ pickup: GANDHIPURAM, drop: BROOKEFIELDS }).expect(200);
    expect(res.body.quotes.map((q: { total: number }) => q.total)).toEqual([38, 72, 145]);
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
    await prisma.driver.update({ where: { id: reg.body.driver.id }, data: { status: 'APPROVED' } });
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
    await http.post(`/v1/trips/${trip.id}/arrived`).set(auth).expect(200);
    await http.post(`/v1/trips/${trip.id}/start`).set(auth).send({ otp: '0000' === trip.otp ? '1111' : '0000' }).expect(400);
    await http.post(`/v1/trips/${trip.id}/start`).set(auth).send({ otp: trip.otp }).expect(200);
    // Ended at the drop (farther than dropRadiusM would need a reason).
    const done = await http.post(`/v1/trips/${trip.id}/complete`).set(auth).send({ lat: BROOKEFIELDS.lat, lng: BROOKEFIELDS.lng }).expect(200);
    await http.post(`/v1/trips/${trip.id}/rate`).set('Authorization', `Bearer ${passenger}`).send({ rating: 5 }).expect(200);

    // Assert
    expect(trip.fareTotal).toBe(38);
    expect(done.body.status).toBe('COMPLETED');
    const history = await http.get('/v1/trips').set('Authorization', `Bearer ${passenger}`).expect(200);
    expect(history.body[0].id).toBe(trip.id);
  });

  /** An approved driver of [vehicleKind], online at [at]. Returns their token. */
  async function onlineDriver(vehicleKind: string, at: { lat: number; lng: number }): Promise<string> {
    const user = await login();
    const plate = `TN 37 ${vehicleKind.slice(0, 2)} ${Math.floor(1000 + Math.random() * 8999)}`;
    const reg = await http
      .post('/v1/drivers')
      .set('Authorization', `Bearer ${user}`)
      .send({ name: 'Test Driver', workType: 'RIDES', vehicleKind, vehicleModel: 'Test', vehicleColor: 'White', plate, upiId: 'test@okaxis' })
      .expect(201);
    await prisma.driver.update({ where: { id: reg.body.driver.id }, data: { status: 'APPROVED' } });
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

    // Assert
    const autoAlt = alts.find((a: { vehicleKind: string }) => a.vehicleKind === 'AUTO');
    expect(autoAlt.quote.total).toBe(72);
    expect(autoAlt.driversNearby).toBeGreaterThan(0);
    expect(alts.map((a: { vehicleKind: string }) => a.vehicleKind)).not.toContain('CAB');
    expect(added.alsoKinds).toEqual(['AUTO']);
    expect(accepted.status).toBe(200);
    expect(accepted.body.vehicleKind).toBe('AUTO');
    expect(accepted.body.fareTotal).toBe(72);
    await http.post(`/v1/trips/${trip.id}/cancel`).set(pax).send({}).expect(200);
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
    const hot = snap.body.cells.find((c: { requests: number }) => c.requests >= 5);
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
  });
});
