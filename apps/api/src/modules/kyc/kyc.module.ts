import { Module } from '@nestjs/common';

import { DiditClient } from './didit.client.js';
import { DriverApprovalService } from './driver-approval.service.js';
import { KycController } from './kyc.controller.js';
import { KycService } from './kyc.service.js';

/** Identity checks with Didit (in-app SDK + webhooks) and the driver approval rules that depend on them. */
@Module({
  controllers: [KycController],
  providers: [DiditClient, KycService, DriverApprovalService],
  exports: [DiditClient, DriverApprovalService],
})
export class KycModule {}
