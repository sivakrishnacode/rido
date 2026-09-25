import { Module } from '@nestjs/common';

import { DriversModule } from '../drivers/drivers.module.js';
import { FaresModule } from '../fares/fares.module.js';
import { MapsModule } from '../maps/maps.module.js';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { DispatchService } from './dispatch.service.js';
import { TripsController } from './trips.controller.js';
import { TripsService } from './trips.service.js';

/** Booking, dispatch and the trip lifecycle. */
@Module({
  imports: [FaresModule, DriversModule, RealtimeModule, MapsModule],
  controllers: [TripsController],
  providers: [TripsService, DispatchService],
})
export class TripsModule {}
