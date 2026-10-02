// End-to-end: driver registration, profile and account features (same set-up as app.e2e-spec.ts: Postgres + Redis,
// a fake Didit). The e2e config runs the files one after another (they share the test database and Redis).
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/core/prisma/prisma.service.js';
import { RedisService } from '../src/core/redis/redis.service.js';
import { DiditClient } from '../src/modules/kyc/didit.client.js';
import { TripEventsService } from '../src/modules/realtime/trip-events.service.js';

const ADMIN_PHONE = '9000000001';
/** A stored photo so drivers approved directly in the database may go online (photo required with Didit on). */
const E2E_PHOTO = '00000000-0000-4000-8000-00000000e2e0.jpg';
/** Smallest valid JPEG header bytes: enough for storage (it only checks the type). */
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0xff, 0xd9]);
const AT = { lat: 11.019, lng: 76.973 };

type Auth = { Authorization: string };

/** Random valid number plate (plates are unique and the test database keeps earlier runs' drivers). */
function randomPlate(): string {
  const letter = () => String.fromCharCode(65 + Math.floor(Math.random() * 26));
  return `TN ${10 + Math.floor(Math.random() * 90)} ${letter()}${letter()}${letter()} ${Math.floor(1000 + Math.random() * 8999)}`;
}

/** Random valid Indian mobile number so runs don't collide. */
function phone(): string {
  return `9${String(Math.floor(Math.random() * 1e9)).padStart(9, '0')}`;
}

/** Stands in for Didit: the next face-match result is set by the test. */
const fakeDidit = {
  isEnabled: true,
  createSession: async (p: { userId: string }) => ({ sessionId: `sess-${p.userId}`, sessionToken: `tok-${p.userId}`, status: 'Not Started' }),
  decision: async (sessionId: string) => ({ session_id: sessionId, status: 'In Progress' }),
  image: async () => null,
  nextMatch: { score: 97 as number | null, faces: 1, isMatch: true },
  faceMatch: async () => fakeDidit.nextMatch,
};

describe('Tamil Taxi features (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let redis: RedisService;
  let http: ReturnType<typeof request>;

  beforeAll(async () => {
    process.env.OTP_DEV_MODE = 'true';
    process.env.ADMIN_PHONES = ADMIN_PHONE;
    process.env.GOOGLE_MAPS_API_KEY = '';
    process.env.DIDIT_API_KEY = 'e2e';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).overrideProvider(DiditClient).useValue(fakeDidit).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health', 'health/ready'] });
    await app.init();
    prisma = app.get(PrismaService);
    redis = app.get(RedisService);
    const keys = [...(await redis.keys('otp:*')), ...(await redis.keys('driver:*')), ...(await redis.keys('h3:*')), ...(await redis.keys('dispatch:*'))];
    if (keys.length) await redis.del(...keys);
    http = request(app.getHttpServer());
  });

  afterAll(async () => {
    await app.close();
  });

  async function login(p = phone()): Promise<{ auth: Auth; userId: string }> {
    await http.post('/v1/auth/otp').send({ phone: p }).expect(200);
    const res = await http.post('/v1/auth/verify').send({ phone: p, code: '123456' }).expect(200);
    return { auth: { Authorization: `Bearer ${res.body.accessToken as string}` }, userId: res.body.user.id as string };
  }

  let adminHeaders: Auth | null = null;
  /** The admin's token, signed in once (OTP sends are limited per phone). */
  async function adminAuth(): Promise<Auth> {
    adminHeaders ??= (await login(ADMIN_PHONE)).auth;
    return adminHeaders;
  }

  function registration(plate = randomPlate()): Record<string, string> {
    return { name: 'Kavin R', workType: 'RIDES', vehicleKind: 'AUTO', vehicleModel: 'Bajaj RE', vehicleColor: 'Green', plate, upiId: 'kavin@okaxis' };
  }

  /** A registered driver (PENDING); returns their token and ids. */
  async function newDriver(): Promise<{ auth: Auth; driverId: string; userId: string; plate: string }> {
    const plate = randomPlate();
    const { auth } = await login();
    const res = await http.post('/v1/drivers').set(auth).send(registration(plate)).expect(201);
    return { auth: { Authorization: `Bearer ${res.body.accessToken as string}` }, driverId: res.body.driver.id, userId: res.body.driver.userId, plate };
  }

  /** An approved driver with a photo (may go online). */
  async function approvedDriver(): Promise<{ auth: Auth; driverId: string; userId: string; plate: string }> {
    const d = await newDriver();
    await prisma.driver.update({ where: { id: d.driverId }, data: { status: 'APPROVED', photoFile: E2E_PHOTO } });
    return d;
  }

  describe('driver registration (POST /drivers)', () => {
    it('answers a repeated registration with the same driver and a fresh token', async () => {
      const { auth, userId } = await login();
      const body = registration();
      const first = await http.post('/v1/drivers').set(auth).send(body).expect(201);
      // The app lost the answer and retries with its old (passenger) token: same driver, 200, a working token.
      const again = await http.post('/v1/drivers').set(auth).send(body).expect(200);
      expect(again.body.driver.id).toBe(first.body.driver.id);
      const me = await http.get('/v1/drivers/me').set({ Authorization: `Bearer ${again.body.accessToken as string}` }).expect(200);
      expect(me.body.id).toBe(first.body.driver.id);
      // One driver, one trial.
      expect(await prisma.driver.count({ where: { userId } })).toBe(1);
      expect(await prisma.subscription.count({ where: { driverId: first.body.driver.id, status: 'TRIAL' } })).toBe(1);
    });

    it('refuses a plate another driver has, with a clear message', async () => {
      const taken = await newDriver();
      const { auth } = await login();
      const res = await http.post('/v1/drivers').set(auth).send(registration(taken.plate.toLowerCase())).expect(409);
      expect(res.body.message).toBe('This number plate is already registered');
    });

    it('refuses an admin (it would demote them)', async () => {
      const admin = await adminAuth();
      await http.post('/v1/drivers').set(admin).send(registration()).expect(403);
      expect((await http.get('/v1/me').set(admin).expect(200)).body.role).toBe('ADMIN');
    });
  });

  describe('profile edits (PATCH /drivers/me)', () => {
    it('a new plate after approval sends the driver back to pending, offline, with the RC to upload again', async () => {
      const d = await approvedDriver();
      await prisma.kycDocument.update({ where: { driverId_type: { driverId: d.driverId, type: 'VEHICLE_RC' } }, data: { status: 'VERIFIED', fileUrl: 'old-rc.jpg' } });
      await http.post('/v1/drivers/me/online').set(d.auth).send(AT).expect(200);
      expect(await redis.get(`driver:cell:${d.driverId}`)).not.toBeNull();

      // Model, colour and UPI change freely; the same plate typed differently is not a change.
      const same = await http.patch('/v1/drivers/me').set(d.auth).send({ vehicleColor: 'Yellow', upiId: 'kavin@oksbi', plate: d.plate.replace(/\s+/g, '').toLowerCase() }).expect(200);
      expect(same.body).toMatchObject({ status: 'APPROVED', isOnline: true, vehicleColor: 'Yellow', plate: d.plate });

      const plate = randomPlate();
      const res = await http.patch('/v1/drivers/me').set(d.auth).send({ plate: plate.toLowerCase() }).expect(200);
      expect(res.body).toMatchObject({ status: 'PENDING', isOnline: false, plate });
      const rc = await prisma.kycDocument.findUniqueOrThrow({ where: { driverId_type: { driverId: d.driverId, type: 'VEHICLE_RC' } } });
      expect(rc).toMatchObject({ status: 'NOT_UPLOADED', fileUrl: null, rejectReason: `Upload the RC of your new vehicle (${plate})` });
      // Out of dispatch like going offline, and it shows in the admin history.
      expect(await redis.get(`driver:cell:${d.driverId}`)).toBeNull();
      expect((await redis.get(`driver:state:${d.driverId}`)) ?? '').not.toMatch(/^1\|/);
      const history = (await http.get(`/v1/admin/users/${d.userId}/activity`).set(await adminAuth()).expect(200)).body as { summary: string }[];
      expect(history.map((h) => h.summary)).toContain(`New plate ${plate} in the app: RC to upload again`);
      await http.post('/v1/drivers/me/online').set(d.auth).send(AT).expect(403);
    });

    it("refuses another driver's plate", async () => {
      const [a, b] = [await approvedDriver(), await newDriver()];
      const res = await http.patch('/v1/drivers/me').set(b.auth).send({ plate: a.plate }).expect(409);
      expect(res.body.message).toBe('This number plate is already registered');
    });

    it('a pending driver mid sign-up just changes the plate', async () => {
      const d = await newDriver();
      const plate = randomPlate();
      expect((await http.patch('/v1/drivers/me').set(d.auth).send({ plate }).expect(200)).body).toMatchObject({ status: 'PENDING', plate });
      // Nothing uploaded yet: no reason shown on the RC.
      const rc = await prisma.kycDocument.findUniqueOrThrow({ where: { driverId_type: { driverId: d.driverId, type: 'VEHICLE_RC' } } });
      expect(rc).toMatchObject({ status: 'NOT_UPLOADED', rejectReason: null });
    });
  });

  describe('admin decisions reach the driver app (driver.status)', () => {
    /** `driver.status` events sent to [driverId]'s room while [act] runs. */
    async function statusEvents(driverId: string, act: () => Promise<unknown>): Promise<unknown[]> {
      const spy = vi.spyOn(app.get(TripEventsService), 'toDriver');
      try {
        await act();
        return spy.mock.calls.filter(([id, event]) => id === driverId && event === 'driver.status').map(([, , payload]) => payload);
      } finally {
        spy.mockRestore();
      }
    }

    it('putting an online driver on hold takes them out of dispatch and tells the app', async () => {
      const admin = await adminAuth();
      const d = await approvedDriver();
      await http.post('/v1/drivers/me/online').set(d.auth).send(AT).expect(200);
      const events = await statusEvents(d.driverId, () => http.patch(`/v1/admin/drivers/${d.driverId}`).set(admin).send({ status: 'ON_HOLD', reason: 'Insurance expired' }).expect(200));
      expect(events).toEqual([{ status: 'ON_HOLD', isOnline: false }]);
      expect(await redis.get(`driver:cell:${d.driverId}`)).toBeNull();
      // Reactivated: approved, still offline until they go online again.
      const back = await statusEvents(d.driverId, () => http.patch(`/v1/admin/drivers/${d.driverId}`).set(admin).send({ status: 'APPROVED' }).expect(200));
      expect(back).toEqual([{ status: 'APPROVED', isOnline: false }]);
    });

    it('taking a driver offline tells the app', async () => {
      const admin = await adminAuth();
      const d = await approvedDriver();
      await http.post('/v1/drivers/me/online').set(d.auth).send(AT).expect(200);
      const events = await statusEvents(d.driverId, () => http.post(`/v1/admin/drivers/${d.driverId}/offline`).set(admin).expect(200));
      expect(events).toEqual([{ status: 'APPROVED', isOnline: false }]);
      expect(await redis.get(`driver:cell:${d.driverId}`)).toBeNull();
    });

    it('a rejected document rejects an online driver, takes them offline and tells the app', async () => {
      const admin = await adminAuth();
      const d = await approvedDriver();
      await http.post('/v1/drivers/me/online').set(d.auth).send(AT).expect(200);
      await prisma.kycDocument.update({ where: { driverId_type: { driverId: d.driverId, type: 'INSURANCE' } }, data: { status: 'UNDER_REVIEW', fileUrl: 'ins.jpg' } });
      const events = await statusEvents(d.driverId, () =>
        http.post(`/v1/admin/drivers/${d.driverId}/documents/INSURANCE`).set(admin).send({ status: 'REJECTED', reason: 'Policy expired' }).expect(201),
      );
      expect(events).toEqual([{ status: 'REJECTED', isOnline: false }]);
      expect(await redis.get(`driver:cell:${d.driverId}`)).toBeNull();
      expect((await http.get('/v1/drivers/me').set(d.auth).expect(200)).body).toMatchObject({ status: 'REJECTED', isOnline: false });
    });
  });
});
