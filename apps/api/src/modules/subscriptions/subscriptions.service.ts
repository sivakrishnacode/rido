import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Plan, Subscription } from '../../generated/prisma/client.js';
import { PlanPeriod, SubscriptionStatus, VehicleKind } from '../../generated/prisma/enums.js';
import { GRACE_DAYS, PERIOD_DAYS, TRIAL_DAYS } from './plan-prices.js';

const DAY_MS = 86_400_000;
type SubscriptionWithPlan = Subscription & { plan: Plan };

/**
 * Driver plans (daily / weekly / monthly) and their lifecycle. Payments are simulated here;
 * plug Razorpay Subscriptions / UPI Autopay into [purchase].
 */
@Injectable()
export class SubscriptionsService {
  constructor(private readonly prisma: PrismaService) {}

  plans(vehicleKind?: VehicleKind): Promise<Plan[]> {
    return this.prisma.plan.findMany({ where: { isActive: true, vehicleKind }, orderBy: [{ vehicleKind: 'asc' }, { price: 'asc' }] });
  }

  /** Latest subscription with its effective status (lapsed plans move to GRACE, then EXPIRED). */
  async current(driverId: string): Promise<SubscriptionWithPlan | null> {
    const sub = await this.prisma.subscription.findFirst({
      where: { driverId },
      orderBy: { endsAt: 'desc' },
      include: { plan: true },
    });
    if (!sub) return null;
    return { ...sub, status: SubscriptionsService.effectiveStatus(sub, new Date()) };
  }

  static effectiveStatus(sub: Subscription, now: Date): SubscriptionStatus {
    const isLive = sub.status === SubscriptionStatus.ACTIVE || sub.status === SubscriptionStatus.TRIAL;
    if (!isLive || now <= sub.endsAt) return sub.status;
    const isInGrace = now.getTime() - sub.endsAt.getTime() <= GRACE_DAYS * DAY_MS;
    return isInGrace ? SubscriptionStatus.GRACE : SubscriptionStatus.EXPIRED;
  }

  async canGoOnline(driverId: string): Promise<boolean> {
    const sub = await this.current(driverId);
    const allowed: SubscriptionStatus[] = [SubscriptionStatus.TRIAL, SubscriptionStatus.ACTIVE, SubscriptionStatus.GRACE];
    return !!sub && allowed.includes(sub.status);
  }

  async startTrial(driverId: string, vehicleKind: VehicleKind): Promise<Subscription> {
    const plan = await this.prisma.plan.findUniqueOrThrow({ where: { vehicleKind_period: { vehicleKind, period: PlanPeriod.MONTHLY } } });
    return this.prisma.subscription.create({
      data: { driverId, planId: plan.id, status: SubscriptionStatus.TRIAL, endsAt: new Date(Date.now() + TRIAL_DAYS * DAY_MS) },
    });
  }

  /** Buys or renews a plan; extends from the later of now and the current end date. */
  async purchase(params: { driverId: string; planId: string; upiApp: string }): Promise<SubscriptionWithPlan> {
    const plan = await this.prisma.plan.findUnique({ where: { id: params.planId } });
    if (!plan || !plan.isActive) throw new NotFoundException('Plan not found');
    const current = await this.current(params.driverId);
    const from = current && current.endsAt > new Date() ? current.endsAt : new Date();
    const endsAt = new Date(from.getTime() + PERIOD_DAYS[plan.period] * DAY_MS);
    return this.prisma.subscription.create({
      data: {
        driverId: params.driverId,
        planId: plan.id,
        status: SubscriptionStatus.ACTIVE,
        startsAt: from,
        endsAt,
        upiApp: params.upiApp,
        autopay: plan.period !== PlanPeriod.DAILY,
        payments: { create: { amount: plan.price, status: 'PAID', providerRef: `sim_${Date.now()}` } },
      },
      include: { plan: true },
    });
  }

  async setStatus(driverId: string, status: SubscriptionStatus): Promise<SubscriptionWithPlan> {
    const current = await this.current(driverId);
    if (!current) throw new BadRequestException('No plan to update');
    return this.prisma.subscription.update({ where: { id: current.id }, data: { status }, include: { plan: true } });
  }
}
