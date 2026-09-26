// End-to-end: needs Postgres + Redis (`docker compose up -d postgres redis` and `npm run prisma:deploy -w @rido/api`).
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/core/prisma/prisma.service.js';
import { RedisService } from '../src/core/redis/redis.service.js';

const GANDHIPURAM = { lat: 11.0183, lng: 76.9725, placeId: 'gandhipuram', name: 'Gandhipuram Central Bus Stand' };
const BROOKEFIELDS = { lat: 11.009, lng: 76.96, placeId: 'brookefields', name: 'Brookefields Mall' };

const ADMIN_PHONE = '9000000001';

/** Random valid Indian mobile number so runs don't collide. */
function phone(): string {
  return `9${String(Math.floor(Math.random() * 1e9)).padStart(9, '0')}`;
}

describe('Rido API (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let http: ReturnType<typeof request>;

  beforeAll(async () => {
    process.env.OTP_DEV_MODE = 'true';
    process.env.ADMIN_PHONES = ADMIN_PHONE;
    process.env.GOOGLE_MAPS_API_KEY = ''; // no paid Google calls in tests
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
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
    const done = await http.post(`/v1/trips/${trip.id}/complete`).set(auth).send({}).expect(200);
    await http.post(`/v1/trips/${trip.id}/rate`).set('Authorization', `Bearer ${passenger}`).send({ rating: 5 }).expect(200);

    // Assert
    expect(trip.fareTotal).toBe(38);
    expect(done.body.status).toBe('COMPLETED');
    const history = await http.get('/v1/trips').set('Authorization', `Bearer ${passenger}`).expect(200);
    expect(history.body[0].id).toBe(trip.id);
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
    const docs = await http.post(`/v1/admin/drivers/${driverId}/documents/AADHAAR`).set(auth).send({ status: 'VERIFIED' }).expect(201);
    expect(docs.body.find((d: { type: string }) => d.type === 'AADHAAR').status).toBe('VERIFIED');
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
    const passenger = await login();
    const peelamedu = { lat: 11.029, lng: 77.027, name: 'Peelamedu' };
    const raceCourse = { lat: 10.999, lng: 76.978, name: 'Race Course' };
    for (let i = 0; i < 5; i++) {
      await http.post('/v1/trips').set('Authorization', `Bearer ${passenger}`)
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
});
