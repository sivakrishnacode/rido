import { Injectable } from '@nestjs/common';

import { DriverStateCache } from '../../core/driver-state/driver-state.cache.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { DriverStatus } from '../../generated/prisma/enums.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { DiditClient } from './didit.client.js';
import { nextDriverStatus } from './driver-approval.js';

/** Re-evaluates a driver's status after a document review or an identity result, and tells them when approved. */
@Injectable()
export class DriverApprovalService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly didit: DiditClient,
    private readonly notifier: NotifierService,
    private readonly driverState: DriverStateCache,
  ) {}

  async recompute(driverId: string): Promise<DriverStatus> {
    const driver = await this.prisma.driver.findUniqueOrThrow({
      where: { id: driverId },
      include: { documents: true, user: { select: { identityStatus: true } } },
    });
    const next = nextDriverStatus({
      current: driver.status,
      docs: driver.documents,
      identity: driver.user.identityStatus,
      isIdentityRequired: this.didit.isEnabled,
    });
    if (next === driver.status) return next;
    await this.prisma.driver.update({ where: { id: driverId }, data: { status: next, isOnline: next === DriverStatus.APPROVED ? undefined : false } });
    await this.driverState.invalidate(driverId);
    if (next === DriverStatus.APPROVED) void this.notifier.kycReviewed({ driverId, status: 'APPROVED' });
    return next;
  }
}
