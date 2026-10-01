import { Injectable } from '@nestjs/common';

import { DriverStateCache } from '../../core/driver-state/driver-state.cache.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { DriverStatus, IdentityStatus, KycStatus } from '../../generated/prisma/enums.js';
import { DiditClient } from '../kyc/didit.client.js';
import { approvalChecklist, type ApprovalChecklist, REQUIRED_DOCS } from '../kyc/driver-approval.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { SettingsService } from '../settings/settings.service.js';
import type { Paged } from './admin.types.js';
import { driverSearch } from './list-filters.js';
import { APPROVAL_STAGES, type ApprovalStage, type ApprovalsQueryDto } from './dto/approvals.dto.js';

const ITEM_SELECT = {
  id: true,
  userId: true,
  status: true,
  workType: true,
  vehicleKind: true,
  vehicleModel: true,
  plate: true,
  photoFile: true,
  pendingPhotoFile: true,
  photoMatchScore: true,
  createdAt: true,
  updatedAt: true,
  user: { select: { id: true, name: true, phone: true, gender: true, identityStatus: true } },
  documents: { where: { type: { in: [...REQUIRED_DOCS] } }, select: { id: true, type: true, status: true, fileUrl: true, rejectReason: true, updatedAt: true } },
} satisfies Prisma.DriverSelect;

type ItemRow = Prisma.DriverGetPayload<{ select: typeof ITEM_SELECT }>;
export type ApprovalItem = ItemRow & { checklist: ApprovalChecklist };

export interface ApprovalsPage extends Paged<ApprovalItem> {
  readonly stage: ApprovalStage;
  /** Drivers in each bucket (the search is not applied). */
  readonly counts: Record<ApprovalStage, number>;
  /** Setting `driverAutoApprove`: off = ready drivers wait here for an admin. */
  readonly autoApprove: boolean;
  /** Didit is set up, so the identity check is one of the steps. */
  readonly identityRequired: boolean;
}

/** The driver approval queue (Drivers › Approvals) and approving several ready drivers at once. */
@Injectable()
export class AdminApprovalsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly didit: DiditClient,
    private readonly settings: SettingsService,
    private readonly notifier: NotifierService,
    private readonly driverState: DriverStateCache,
  ) {}

  /** Where clause of one bucket. Pending drivers fall in exactly one of ready / documents / identity / driver. */
  private where(stage: ApprovalStage): Prisma.DriverWhereInput {
    const pending = { status: DriverStatus.PENDING };
    const ready: Prisma.DriverWhereInput = {
      AND: [
        ...REQUIRED_DOCS.map((type) => ({ documents: { some: { type, status: KycStatus.VERIFIED } } })),
        ...(this.didit.isEnabled ? [{ user: { identityStatus: IdentityStatus.APPROVED } }] : []),
      ],
    };
    const documents: Prisma.DriverWhereInput = { documents: { some: { type: { in: [...REQUIRED_DOCS] }, status: KycStatus.UNDER_REVIEW } } };
    const identity: Prisma.DriverWhereInput | null = this.didit.isEnabled ? { user: { identityStatus: IdentityStatus.IN_REVIEW } } : null;
    switch (stage) {
      case 'ready':
        return { ...pending, ...ready };
      case 'documents':
        return { ...pending, ...documents };
      case 'identity':
        return identity ? { ...pending, ...identity, NOT: [documents] } : { id: { in: [] } };
      case 'driver':
        return { ...pending, NOT: [ready, documents, ...(identity ? [identity] : [])] };
      case 'photos':
        return { pendingPhotoFile: { not: null } };
    }
  }

  async list(q: ApprovalsQueryDto): Promise<ApprovalsPage> {
    const stage = q.stage ?? 'ready';
    const page = q.page ?? 1;
    const pageSize = q.pageSize ?? 20;
    const search = driverSearch(q.q);
    const where: Prisma.DriverWhereInput = search ? { AND: [this.where(stage), search] } : this.where(stage);
    const [rows, total, counts, autoApprove] = await Promise.all([
      this.prisma.driver.findMany({ where, select: ITEM_SELECT, orderBy: { updatedAt: 'asc' }, skip: (page - 1) * pageSize, take: pageSize }),
      this.prisma.driver.count({ where }),
      Promise.all(APPROVAL_STAGES.map((s) => this.prisma.driver.count({ where: this.where(s) }))),
      this.settings.get('driverAutoApprove'),
    ]);
    const isIdentityRequired = this.didit.isEnabled;
    return {
      items: rows.map((d) => ({ ...d, checklist: approvalChecklist({ docs: d.documents, identity: d.user.identityStatus, isIdentityRequired }) })),
      total,
      page,
      pageSize,
      stage,
      counts: Object.fromEntries(APPROVAL_STAGES.map((s, i) => [s, counts[i]])) as Record<ApprovalStage, number>,
      autoApprove,
      identityRequired: isIdentityRequired,
    };
  }

  /**
   * Approves the pending drivers whose every check is done; the rest are skipped with the reason. Each approval gets its
   * own audit row on the driver (the request's row has no driver id), so a driver's history shows only real approvals.
   */
  async approveMany(ids: readonly string[], actorId: string): Promise<{ approved: string[]; skipped: { id: string; reason: string }[] }> {
    const unique = [...new Set(ids)];
    const drivers = await this.prisma.driver.findMany({
      where: { id: { in: unique } },
      select: { id: true, status: true, documents: { select: { type: true, status: true } }, user: { select: { identityStatus: true } } },
    });
    const approved: string[] = [];
    const skipped: { id: string; reason: string }[] = unique.filter((id) => !drivers.some((d) => d.id === id)).map((id) => ({ id, reason: 'Not found' }));
    for (const d of drivers) {
      if (d.status !== DriverStatus.PENDING) {
        skipped.push({ id: d.id, reason: `Already ${d.status.toLowerCase().replace('_', ' ')}` });
        continue;
      }
      const check = approvalChecklist({ docs: d.documents, identity: d.user.identityStatus, isIdentityRequired: this.didit.isEnabled });
      if (!check.isReady) {
        skipped.push({ id: d.id, reason: 'Checks not done' });
        continue;
      }
      // Only still-pending rows: a driver held or approved meanwhile is left alone.
      const { count } = await this.prisma.driver.updateMany({ where: { id: d.id, status: DriverStatus.PENDING }, data: { status: DriverStatus.APPROVED } });
      if (!count) {
        skipped.push({ id: d.id, reason: 'Changed meanwhile' });
        continue;
      }
      await this.driverState.invalidate(d.id);
      void this.notifier.kycReviewed({ driverId: d.id, status: 'APPROVED' });
      await this.prisma.auditLog.create({
        data: { actorId, action: 'POST /v1/admin/drivers/approve', entity: 'drivers', entityId: d.id, data: { body: { status: 'APPROVED' }, bulk: true } },
      });
      approved.push(d.id);
    }
    return { approved, skipped };
  }
}
