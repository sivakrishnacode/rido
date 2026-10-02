import { ForbiddenException } from '@nestjs/common';
import type { JwtService } from '@nestjs/jwt';
import type { Socket } from 'socket.io';

import type { AuthUser } from '../../core/auth/auth-user.js';
import type { UserAccessService } from '../../core/auth/user-access.service.js';
import type { PrismaService } from '../../core/prisma/prisma.service.js';
import type { LocationIngestService } from './location-ingest.service.js';
import { RealtimeGateway } from './realtime.gateway.js';
import type { TripEventsService } from './trip-events.service.js';

function socket(): Socket & { rooms: string[]; disconnected: boolean } {
  const s = {
    handshake: { auth: { token: 'jwt' } },
    data: {},
    rooms: [] as string[],
    disconnected: false,
    join: async (room: string) => void s.rooms.push(room),
    disconnect: () => void (s.disconnected = true),
  };
  return s as unknown as Socket & { rooms: string[]; disconnected: boolean };
}

function gateway(resolve: () => Promise<AuthUser>): RealtimeGateway {
  const jwt = { verifyAsync: async () => ({ sub: 'u1', role: 'DRIVER' }) } as unknown as JwtService;
  const access = { resolve } as unknown as UserAccessService;
  return new RealtimeGateway(jwt, {} as TripEventsService, {} as LocationIngestService, {} as PrismaService, access);
}

describe('RealtimeGateway.handleConnection', () => {
  it("joins the user's room and the current driver profile's room", async () => {
    const s = socket();
    await gateway(async () => ({ userId: 'u1', role: 'DRIVER', driverId: 'd1' })).handleConnection(s);
    expect(s.rooms).toEqual(['user:u1', 'driver:d1']);
    expect(s.disconnected).toBe(false);
  });

  it('disconnects a blocked account', async () => {
    const s = socket();
    await gateway(async () => {
      throw new ForbiddenException('Your account is blocked. Contact support.');
    }).handleConnection(s);
    expect(s.disconnected).toBe(true);
    expect(s.rooms).toEqual([]);
  });
});
