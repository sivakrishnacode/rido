import { Module } from '@nestjs/common';

import { DriversModule } from '../drivers/drivers.module.js';
import { LocationIngestService } from './location-ingest.service.js';
import { LocationsController } from './locations.controller.js';
import { RealtimeGateway } from './realtime.gateway.js';
import { TripEventsService } from './trip-events.service.js';
import { TripTrackService } from './trip-track.service.js';

/** Socket.IO gateway, driver GPS uploads (socket and HTTP) and the event emitter used by trips. */
@Module({
  imports: [DriversModule],
  controllers: [LocationsController],
  providers: [RealtimeGateway, TripEventsService, LocationIngestService, TripTrackService],
  exports: [TripEventsService, TripTrackService],
})
export class RealtimeModule {}
