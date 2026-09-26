import { Global, Module } from '@nestjs/common';

import { DevicesController } from './devices.controller.js';
import { NotifierService } from './notifier.service.js';
import { PushService } from './push.service.js';

/** Push notifications (FCM). Global so trips, dispatch, chat and admin can notify without import cycles. */
@Global()
@Module({
  controllers: [DevicesController],
  providers: [PushService, NotifierService],
  exports: [PushService, NotifierService],
})
export class NotificationsModule {}
