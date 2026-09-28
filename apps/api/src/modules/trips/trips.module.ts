import { Module } from '@nestjs/common';

import { DriversModule } from '../drivers/drivers.module.js';
import { FaresModule } from '../fares/fares.module.js';
import { MapsModule } from '../maps/maps.module.js';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { DispatchService } from './dispatch.service.js';
import { DriverBlocksController } from './driver-blocks.controller.js';
import { DriverBlocksService } from './driver-blocks.service.js';
import { TripChatService } from './trip-chat.service.js';
import { TripOtpGuard } from './trip-otp-guard.js';
import { TripTimeoutsService } from './trip-timeouts.service.js';
import { TripsController } from './trips.controller.js';
import { TripsService } from './trips.service.js';

/** Booking, dispatch and the trip lifecycle. */
@Module({
  imports: [FaresModule, DriversModule, RealtimeModule, MapsModule],
  controllers: [TripsController, DriverBlocksController],
  providers: [TripsService, DispatchService, TripChatService, TripOtpGuard, TripTimeoutsService, DriverBlocksService],
  exports: [DriverBlocksService],
})
export class TripsModule {}
