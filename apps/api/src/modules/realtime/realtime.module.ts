import { Module } from '@nestjs/common';

import { DriversModule } from '../drivers/drivers.module.js';
import { RealtimeGateway } from './realtime.gateway.js';
import { TripEventsService } from './trip-events.service.js';

/** Socket.IO gateway and the event emitter used by trips. */
@Module({ imports: [DriversModule], providers: [RealtimeGateway, TripEventsService], exports: [TripEventsService] })
export class RealtimeModule {}
