import { Controller, ForbiddenException, Get } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import { Role } from '../../generated/prisma/enums.js';
import { type CancelRateStats, DriverBlocksService } from './driver-blocks.service.js';

/** The driver's own cancellation rate (D-13 banner) and pause. */
@Controller()
export class DriverBlocksController {
  constructor(private readonly blocks: DriverBlocksService) {}

  @Roles(Role.DRIVER)
  @Get('drivers/me/cancel-rate')
  cancelRate(@CurrentUser() user: AuthUser): Promise<CancelRateStats> {
    if (!user.driverId) throw new ForbiddenException('Register as a driver first');
    return this.blocks.stats(user.driverId);
  }
}
