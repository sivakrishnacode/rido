import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module.js';
import { DriverLocationService } from './driver-location.service.js';
import { DriversController } from './drivers.controller.js';
import { DriversService } from './drivers.service.js';

/** Driver registration, KYC, online status and live locations. */
@Module({
  imports: [AuthModule, SubscriptionsModule],
  controllers: [DriversController],
  providers: [DriversService, DriverLocationService],
  exports: [DriversService, DriverLocationService],
})
export class DriversModule {}
