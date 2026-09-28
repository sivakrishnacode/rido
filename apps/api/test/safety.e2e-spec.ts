// End-to-end safety flows (share links, SOS, stop / route checks). Same set-up as app.e2e-spec.ts; the e2e config
// runs the files one after another (they share the test database and Redis).
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/core/prisma/prisma.service.js';
import { RedisService } from '../src/core/redis/redis.service.js';

const GANDHIPURAM = { lat: 11.0183, lng: 76.9725, placeId: 'gandhipuram', name: 'Gandhipuram Central Bus Stand' };
const BROOKEFIELDS = { lat: 11.009, lng: 76.96, placeId: 'brookefields', name: 'Brookefields Mall' };
/** A stored photo so drivers approved directly in the database may go online. */
const E2E_PHOTO = '00000000-0000-4000-8000-00000000e2e0.jpg';

type Auth = { Authorization: string };

function randomPlate(): string {
  const letter = () => String.fromCharCode(65 + Math.floor(Math.random() * 26));
  return `TN ${10 + Math.floor(Math.random() * 90)} ${letter()}${letter()}${letter()} ${Math.floor(1000 + Math.random() * 8999)}`;
}

function phone(): string {
  return `9${String(Math.floor(Math.random() * 1e9)).padStart(9, '0')}`;
}

describe('Rido safety (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let redis: RedisService;
  let http: ReturnType<typeof request>;

  beforeAll(async () => {
    process.env.OTP_DEV_MODE = 'true';
    process.env.GOOGLE_MAPS_API_KEY = '';
    process.env.DIDIT_API_KEY = '';
    process.env.SHARE_BASE_URL = 'https://track.example.test';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health', 'health/ready'] });
    await app.init();
    prisma = app.get(PrismaService);
    redis = app.get(RedisService);
    const keys = [...(await redis.keys('otp:*')), ...(await redis.keys('h3:*')), ...(await redis.keys('driver:*')), ...(await redis.keys('dispatch:*')), ...(await redis.keys('rl:*'))];
    if (keys.length) await redis.del(...keys);
    http = request(app.getHttpServer());
  });

  afterAll(async () => {
    await app.close();
  });

  async function login(p = phone()): Promise<Auth> {
    await http.post('/v1/auth/otp').send({ phone: p }).expect(200);
    const res = await http.post('/v1/auth/verify').send({ phone: p, code: '123456' }).expect(200);
    return { Authorization: `Bearer ${res.body.accessToken as string}` };
  }

  /** Only this bike driver is indexed, online at the pickup; a new rider books a bike ride and the driver accepts. */
  async function assignedBikeTrip() {
    const cells = await redis.keys('h3:drv:BIKE:*');
    if (cells.length) await redis.del(...cells);
    const user = await login();
    const reg = await http
      .post('/v1/drivers')
      .set(user)
      .send({ name: 'Selvam Raj', workType: 'RIDES', vehicleKind: 'BIKE', vehicleModel: 'TVS Jupiter', vehicleColor: 'Blue', plate: randomPlate(), upiId: 'selvam@okaxis' })
      .expect(201);
    await prisma.driver.update({ where: { id: reg.body.driver.id }, data: { status: 'APPROVED', photoFile: E2E_PHOTO } });
    const driver = { Authorization: `Bearer ${reg.body.accessToken as string}` };
    await http.post('/v1/drivers/me/online').set(driver).send({ lat: 11.019, lng: 76.973 }).expect(200);
    const pax = await login();
    const trip = (await http.post('/v1/trips').set(pax).send({ kind: 'RIDE', vehicleKind: 'BIKE', pickup: GANDHIPURAM, drop: BROOKEFIELDS }).expect(201)).body;
    let status = 0;
    for (let i = 0; i < 40 && status !== 200; i++) {
      status = (await http.post(`/v1/trips/${trip.id}/accept`).set(driver)).status;
      if (status !== 200) await new Promise((r) => setTimeout(r, 250));
    }
    expect(status).toBe(200);
    return { trip, driver, pax, driverId: reg.body.driver.id as string };
  }

  /** Arrive and start the ride (the driver is at the pickup). */
  async function startRide(t: { trip: { id: string; otp: string }; driver: Auth }): Promise<void> {
    await http.post('/v1/drivers/me/location').set(t.driver).send({ lat: GANDHIPURAM.lat, lng: GANDHIPURAM.lng }).expect(204);
    await http.post(`/v1/trips/${t.trip.id}/arrived`).set(t.driver).expect(200);
    await http.post(`/v1/trips/${t.trip.id}/start`).set(t.driver).send({ otp: t.trip.otp }).expect(200);
  }

  it('shares a live trip link: public, minimal, and it expires 30 min after the trip ends', async () => {
    const t = await assignedBikeTrip();
    const link = (await http.post(`/v1/trips/${t.trip.id}/share`).set(t.pax).expect(200)).body;
    expect(link.url).toBe(`https://track.example.test/track/${link.token}`);
    // Only the passenger makes links; a stranger can't.
    const stranger = await login();
    await http.post(`/v1/trips/${t.trip.id}/share`).set(stranger).expect(403);

    // Public read (no token): driver's first name, vehicle, plate, live position; no phone numbers or OTP.
    await http.post('/v1/drivers/me/location').set(t.driver).send({ lat: 11.0185, lng: 76.9727 }).expect(204);
    const view = (await http.get(`/v1/share/${link.token}`).expect(200)).body;
    expect(view).toMatchObject({
      status: 'DRIVER_ASSIGNED',
      isLive: true,
      driver: { firstName: 'Selvam', vehicleModel: 'TVS Jupiter', vehicleColor: 'Blue', vehicleKind: 'BIKE' },
      location: { lat: 11.0185, lng: 76.9727 },
      pickup: { name: GANDHIPURAM.name },
      drop: { name: BROOKEFIELDS.name },
      etaTo: 'pickup',
    });
    expect(view.etaMin).toBeGreaterThanOrEqual(1);
    const raw = JSON.stringify(view);
    expect(raw).not.toMatch(/\+91|phone|otp/i);

    // A tampered token is not found.
    await http.get(`/v1/share/${link.token.slice(0, -1)}${link.token.endsWith('A') ? 'B' : 'A'}`).expect(404);

    // The trip ends: the link keeps working (no live position) for 30 min, then 410.
    await startRide(t);
    await http.post('/v1/drivers/me/location').set(t.driver).send({ lat: BROOKEFIELDS.lat, lng: BROOKEFIELDS.lng }).expect(204);
    await http.post(`/v1/trips/${t.trip.id}/complete`).set(t.driver).send({}).expect(200);
    expect((await http.get(`/v1/share/${link.token}`).expect(200)).body).toMatchObject({ status: 'COMPLETED', isLive: false, location: null });
    await prisma.trip.update({ where: { id: t.trip.id }, data: { endedAt: new Date(Date.now() - 31 * 60_000) } });
    await http.get(`/v1/share/${link.token}`).expect(410);
    await http.post(`/v1/trips/${t.trip.id}/share`).set(t.pax).expect(410);
    await http.post('/v1/drivers/me/offline').set(t.driver);
  }, 45_000);

  it('rate limits public share reads per IP', async () => {
    await redis.del('rl:share:ip:10.9.8.7');
    for (let i = 0; i < 60; i++) await http.get('/v1/share/nope.1.aaaaaaaaaaaaaaaaaaaaaa').set('x-forwarded-for', '10.9.8.7').expect(404);
    expect((await http.get('/v1/share/nope.1.aaaaaaaaaaaaaaaaaaaaaa').set('x-forwarded-for', '10.9.8.7').expect(429)).body.code).toBe('RATE_LIMITED');
  });
});
