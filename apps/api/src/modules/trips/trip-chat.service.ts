import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { RedisService } from '../../core/redis/redis.service.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { TripsService } from './trips.service.js';

const KEEP_S = 24 * 3600;
const MAX_MESSAGES = 200;

export interface ChatMessage {
  id: string;
  from: 'PASSENGER' | 'DRIVER';
  text: string;
  at: string;
}

/** In-trip chat between passenger and driver (P-15 / D-16). Kept in Redis for a day; pushed as `trip.message`. */
@Injectable()
export class TripChatService {
  constructor(
    private readonly redis: RedisService,
    private readonly trips: TripsService,
    private readonly events: TripEventsService,
    private readonly notifier: NotifierService,
  ) {}

  async list(user: AuthUser, tripId: string): Promise<ChatMessage[]> {
    await this.trips.get(user, tripId); // participants only
    const raw = await this.redis.lrange(TripChatService.key(tripId), 0, -1);
    return raw.map((r) => JSON.parse(r) as ChatMessage);
  }

  async send(user: AuthUser, tripId: string, text: string): Promise<ChatMessage> {
    const trip = await this.trips.get(user, tripId);
    const message: ChatMessage = {
      id: randomUUID(),
      from: trip.passengerId === user.userId ? 'PASSENGER' : 'DRIVER',
      text: text.trim(),
      at: new Date().toISOString(),
    };
    const key = TripChatService.key(tripId);
    await this.redis.rpush(key, JSON.stringify(message));
    await this.redis.ltrim(key, -MAX_MESSAGES, -1);
    await this.redis.expire(key, KEEP_S);
    this.events.toTrip(tripId, 'trip.message', { tripId, ...message });
    void this.notifier.chat({ tripId, from: message.from, text: message.text });
    return message;
  }

  private static key(tripId: string): string {
    return `trip:chat:${tripId}`;
  }
}
