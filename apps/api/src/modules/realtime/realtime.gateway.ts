import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';

import type { JwtPayload } from '../../core/auth/auth-user.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { TripEventsService } from './trip-events.service.js';

interface SocketData {
  user?: JwtPayload;
}

/**
 * Socket.IO namespace `/rt`. Connect with `auth: { token: <JWT> }`.
 * Client → server: `trip:join {tripId}`, `driver:location {lat, lng}`.
 * Server → client: `trip.offer`, `trip.updated`, `trip.location`, `trip.no_drivers`.
 */
@WebSocketGateway({ namespace: '/rt', cors: { origin: '*' } })
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly events: TripEventsService,
    private readonly location: DriverLocationService,
    private readonly prisma: PrismaService,
  ) {}

  afterInit(server: Server): void {
    this.events.attach(server);
  }

  async handleConnection(client: Socket): Promise<void> {
    try {
      const token = (client.handshake.auth as { token?: string }).token ?? '';
      const user = await this.jwt.verifyAsync<JwtPayload>(token);
      (client.data as SocketData).user = user;
      await client.join(`user:${user.sub}`);
      if (user.driverId) await client.join(`driver:${user.driverId}`);
    } catch {
      this.logger.debug('Socket rejected: bad token');
      client.disconnect(true);
    }
  }

  @SubscribeMessage('trip:join')
  async joinTrip(@ConnectedSocket() client: Socket, @MessageBody() body: { tripId: string }): Promise<{ ok: boolean }> {
    const user = (client.data as SocketData).user;
    if (!user) return { ok: false };
    const trip = await this.prisma.trip.findUnique({ where: { id: body.tripId } });
    const isParticipant = !!trip && (trip.passengerId === user.sub || (!!user.driverId && trip.driverId === user.driverId));
    if (isParticipant) await client.join(`trip:${body.tripId}`);
    return { ok: isParticipant };
  }

  /** Driver GPS: updates the GEO set and streams to the passenger of the active trip. */
  @SubscribeMessage('driver:location')
  async driverLocation(@ConnectedSocket() client: Socket, @MessageBody() body: { lat: number; lng: number }): Promise<void> {
    const user = (client.data as SocketData).user;
    if (!user?.driverId || !Number.isFinite(body.lat) || !Number.isFinite(body.lng)) return;
    const driver = await this.prisma.driver.findUnique({ where: { id: user.driverId } });
    if (!driver?.isOnline) return;
    await this.location.update({ driverId: driver.id, kind: driver.vehicleKind, lat: body.lat, lng: body.lng });
    const tripId = await this.location.activeTrip(driver.id);
    if (tripId) this.events.toTrip(tripId, 'trip.location', { tripId, lat: body.lat, lng: body.lng, at: Date.now() });
  }
}
