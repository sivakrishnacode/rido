import { Body, Controller, ForbiddenException, Get, HttpCode, Post, Query } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Public } from '../../core/auth/public.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import type { Payment, Plan, Subscription } from '../../generated/prisma/client.js';
import { Role, SubscriptionStatus, VehicleKind } from '../../generated/prisma/enums.js';
import { AutopayDto } from './dto/autopay.dto.js';
import { PurchasePlanDto } from './dto/purchase-plan.dto.js';
import { SubscriptionsService } from './subscriptions.service.js';

/** D-11, D-12, D-24, D-25. */
@Controller()
export class SubscriptionsController {
  constructor(private readonly subs: SubscriptionsService) {}

  @Public()
  @Get('plans')
  plans(@Query('vehicleKind') vehicleKind?: VehicleKind): Promise<Plan[]> {
    return this.subs.plans(vehicleKind);
  }

  @Roles(Role.DRIVER)
  @Get('subscriptions/me')
  current(@CurrentUser() user: AuthUser): Promise<Subscription | null> {
    return this.subs.current(SubscriptionsController.driverId(user));
  }

  @Roles(Role.DRIVER)
  @Get('subscriptions/me/payments')
  payments(@CurrentUser() user: AuthUser): Promise<Payment[]> {
    return this.subs.payments(SubscriptionsController.driverId(user));
  }

  @Roles(Role.DRIVER)
  @Post('subscriptions')
  purchase(@CurrentUser() user: AuthUser, @Body() body: PurchasePlanDto): Promise<Subscription> {
    return this.subs.purchase({ driverId: SubscriptionsController.driverId(user), ...body });
  }

  @Roles(Role.DRIVER)
  @Post('subscriptions/me/autopay')
  @HttpCode(200)
  autopay(@CurrentUser() user: AuthUser, @Body() body: AutopayDto): Promise<Subscription> {
    return this.subs.setupAutopay(SubscriptionsController.driverId(user), body.upiApp);
  }

  @Roles(Role.DRIVER)
  @Post('subscriptions/me/pause')
  @HttpCode(200)
  pause(@CurrentUser() user: AuthUser): Promise<Subscription> {
    return this.subs.setStatus(SubscriptionsController.driverId(user), SubscriptionStatus.PAUSED);
  }

  @Roles(Role.DRIVER)
  @Post('subscriptions/me/resume')
  @HttpCode(200)
  resume(@CurrentUser() user: AuthUser): Promise<Subscription> {
    return this.subs.setStatus(SubscriptionsController.driverId(user), SubscriptionStatus.ACTIVE);
  }

  @Roles(Role.DRIVER)
  @Post('subscriptions/me/cancel')
  @HttpCode(200)
  cancel(@CurrentUser() user: AuthUser): Promise<Subscription> {
    return this.subs.setStatus(SubscriptionsController.driverId(user), SubscriptionStatus.CANCELLED);
  }

  private static driverId(user: AuthUser): string {
    if (!user.driverId) throw new ForbiddenException('Register as a driver first');
    return user.driverId;
  }
}
