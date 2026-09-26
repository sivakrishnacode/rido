import { Body, Controller, Delete, HttpCode, Param, Post } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { RegisterDeviceDto } from './dto/register-device.dto.js';
import { PushService } from './push.service.js';

/** The apps register their FCM token after sign-in (and on token refresh) and remove it on sign-out. */
@Controller('me/devices')
export class DevicesController {
  constructor(private readonly push: PushService) {}

  @Post()
  @HttpCode(204)
  register(@CurrentUser() user: AuthUser, @Body() body: RegisterDeviceDto): Promise<void> {
    return this.push.register({ userId: user.userId, ...body });
  }

  @Delete(':token')
  @HttpCode(204)
  unregister(@CurrentUser() user: AuthUser, @Param('token') token: string): Promise<void> {
    return this.push.unregister(user.userId, token);
  }
}
