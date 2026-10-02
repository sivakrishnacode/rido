import { Injectable, type OnModuleInit } from '@nestjs/common';

import { DriverStateCache } from '../../core/driver-state/driver-state.cache.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Driver } from '../../generated/prisma/client.js';
import { DriverStatus } from '../../generated/prisma/enums.js';
import { DriversService } from '../drivers/drivers.service.js';
import { DriverApprovalService } from '../kyc/driver-approval.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';

/** Socket event the driver app gets on `driver:<id>` when an admin (or a KYC decision) changes the account. */
export const DRIVER_STATUS_EVENT = 'driver.status';

/** Payload of [DRIVER_STATUS_EVENT]. */
export interface DriverStatusEvent {
  readonly status: DriverStatus;
  readonly isOnline: boolean;
}

/**
 * After an admin decision (status change, take offline, bulk approval) or a KYC decision that changes the status
 * (DriverApprovalService.recompute, e.g. a rejected document): a driver who may not take rides any more leaves
 * dispatch like going offline (index, state cache, online session), and the driver app hears it at once
 * (`driver.status` {status, isOnline}) instead of on its next poll.
 */
@Injectable()
export class DriverStatusSync implements OnModuleInit {
  constructor(
    private readonly prisma: PrismaService,
    private readonly drivers: DriversService,
    private readonly events: TripEventsService,
    private readonly approval: DriverApprovalService,
    private readonly state: DriverStateCache,
  ) {}

  onModuleInit(): void {
    this.approval.onStatusChange((driverId) => this.changed(driverId));
  }

  /** Applies the driver's current status (offline unless APPROVED; [offline] = always) and tells their app. */
  async changed(driverId: string, options: { offline?: boolean } = {}): Promise<Driver> {
    let driver = await this.prisma.driver.findUniqueOrThrow({ where: { id: driverId } });
    if (options.offline || driver.status !== DriverStatus.APPROVED) {
      driver = await this.drivers.goOffline(driverId);
      // goOffline caches "not blocked": read the block flag again on the next fix.
      await this.state.invalidate(driverId);
    }
    this.events.toDriver(driverId, DRIVER_STATUS_EVENT, { status: driver.status, isOnline: driver.isOnline } satisfies DriverStatusEvent);
    return driver;
  }
}
