import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module.js';
import { DriverEarningsService } from './driver-earnings.service.js';
import { DriverLocationService } from './driver-location.service.js';
import { DriversController } from './drivers.controller.js';
import { DriversService } from './drivers.service.js';

/** Driver registration, profile, KYC uploads, online status, earnings and live locations. */
@Module({
  imports: [AuthModule, SubscriptionsModule],
  controllers: [DriversController],
  providers: [DriversService, DriverLocationService, DriverEarningsService],
  exports: [DriversService, DriverLocationService],
})
export class DriversModule {}
