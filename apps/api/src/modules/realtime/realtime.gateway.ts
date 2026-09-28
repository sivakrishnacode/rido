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
import { type IngestResult, LocationIngestService } from './location-ingest.service.js';
import { TripEventsService } from './trip-events.service.js';

interface SocketData {
  user?: JwtPayload;
}

/**
 * Socket.IO namespace `/rt`. Connect with `auth: { token: <JWT> }`.
 * Client → server: `trip:join {tripId}`, `driver:location {lat, lng, ts?, acc?, spd?, hdg?, mock?}`,
 * `driver:locations {fixes: [...]}` (fixes buffered while offline; acked with `{ok, accepted}`).
 * Server → client: `trip.offer`, `trip.updated`, `trip.location`, `trip.no_drivers`, `safety.check` (passenger).
 */
@WebSocketGateway({ namespace: '/rt', cors: { origin: '*' } })
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly events: TripEventsService,
    private readonly ingest: LocationIngestService,
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

  /** Driver GPS: updates the dispatch index and streams to the passenger of the active trip. */
  @SubscribeMessage('driver:location')
  async driverLocation(@ConnectedSocket() client: Socket, @MessageBody() body: unknown): Promise<void> {
    const user = (client.data as SocketData).user;
    if (user?.driverId) await this.ingest.live(user.driverId, body);
  }

  /** Fixes the app buffered while the socket was down, oldest first. The ack tells it they can be dropped. */
  @SubscribeMessage('driver:locations')
  async driverLocations(@ConnectedSocket() client: Socket, @MessageBody() body: unknown): Promise<{ ok: boolean } & Partial<IngestResult>> {
    const user = (client.data as SocketData).user;
    if (!user?.driverId) return { ok: false };
    const fixes = Array.isArray(body) ? body : (body as { fixes?: unknown } | null)?.fixes;
    return { ok: true, ...(await this.ingest.batch(user.driverId, fixes)) };
  }
}
