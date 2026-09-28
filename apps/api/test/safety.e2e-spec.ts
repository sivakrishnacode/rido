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
const ADMIN_PHONE = '9000000001';
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
    process.env.ADMIN_PHONES = ADMIN_PHONE;
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

  let admin: Auth | null = null;
  /** The admin's token, signed in once (OTP sends are limited per phone). */
  async function adminAuth(): Promise<Auth> {
    admin ??= await login(ADMIN_PHONE);
    return admin;
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

  it('SOS: passenger or driver raises it, admins acknowledge and resolve it (audit logged)', async () => {
    const t = await assignedBikeTrip();
    const adm = await adminAuth();
    const stranger = await login();
    await http.post(`/v1/trips/${t.trip.id}/sos`).set(stranger).send({}).expect(403);

    // The passenger presses SOS with the phone's fix: recorded, linked on the trip, answered with a live link.
    const res = (await http.post(`/v1/trips/${t.trip.id}/sos`).set(t.pax).send({ lat: 11.0184, lng: 76.9726 }).expect(200)).body;
    expect(res.sos).toMatchObject({ tripId: t.trip.id, role: 'PASSENGER', status: 'OPEN', source: 'BUTTON', lat: 11.0184, lng: 76.9726 });
    expect(res.shareUrl).toMatch(/^https:\/\/track\.example\.test\/track\//);
    // A double tap returns the same SOS.
    expect((await http.post(`/v1/trips/${t.trip.id}/sos`).set(t.pax).send({}).expect(200)).body.sos.id).toBe(res.sos.id);
    // The driver's SOS has no fix from the phone: their last GPS fix is used.
    await http.post('/v1/drivers/me/location').set(t.driver).send({ lat: 11.019, lng: 76.9731 }).expect(204);
    const drv = (await http.post(`/v1/trips/${t.trip.id}/sos`).set(t.driver).send({ note: 'Passenger is aggressive' }).expect(200)).body.sos;
    expect(drv).toMatchObject({ role: 'DRIVER', lat: 11.019, lng: 76.9731, note: 'Passenger is aggressive' });

    // Admin queue: open ones first; the trip page shows the SOS and its SOS_LINKED events.
    const list = (await http.get('/v1/admin/sos?status=active').set(adm).expect(200)).body;
    expect(list.open).toBeGreaterThanOrEqual(2);
    expect(list.items.map((i: { id: string }) => i.id)).toEqual(expect.arrayContaining([res.sos.id, drv.id]));
    const tripPage = (await http.get(`/v1/admin/trips/${t.trip.id}`).set(adm).expect(200)).body;
    expect(tripPage.sos).toHaveLength(2);
    expect(tripPage.safetyEvents.filter((e: { kind: string }) => e.kind === 'SOS_LINKED')).toHaveLength(2);

    // Acknowledge (once), then resolve with a note; a closed SOS can't be resolved again. Both are audit logged.
    expect((await http.post(`/v1/admin/sos/${res.sos.id}/ack`).set(adm).expect(200)).body.status).toBe('ACKNOWLEDGED');
    await http.post(`/v1/admin/sos/${res.sos.id}/ack`).set(adm).expect(409);
    const done = (await http.post(`/v1/admin/sos/${res.sos.id}/resolve`).set(adm).send({ status: 'RESOLVED', note: 'Called the rider, all fine' }).expect(200)).body;
    expect(done).toMatchObject({ status: 'RESOLVED', note: 'Called the rider, all fine' });
    expect(done.resolvedBy).toBeTruthy();
    await http.post(`/v1/admin/sos/${res.sos.id}/resolve`).set(adm).send({ status: 'FALSE_ALARM' }).expect(409);
    expect((await http.post(`/v1/admin/sos/${drv.id}/resolve`).set(adm).send({ status: 'FALSE_ALARM' }).expect(200)).body).toMatchObject({ status: 'FALSE_ALARM' });
    await http.post(`/v1/admin/sos/${drv.id}/resolve`).set(t.pax).send({ status: 'RESOLVED' }).expect(403);
    // The audit interceptor writes after the response.
    await new Promise((r) => setTimeout(r, 200));
    const audit = await prisma.auditLog.findMany({ where: { entity: 'sos', entityId: res.sos.id } });
    expect(audit.map((a) => a.action).sort()).toEqual(['POST /v1/admin/sos/:id/ack', 'POST /v1/admin/sos/:id/resolve']);
    await http.post('/v1/drivers/me/offline').set(t.driver);
  }, 45_000);
});
