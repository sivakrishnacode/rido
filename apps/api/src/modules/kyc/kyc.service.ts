import { ConflictException, HttpException, HttpStatus, Inject, Injectable, Logger, NotFoundException, ServiceUnavailableException } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import type { Env } from '../../core/config/env.js';
import { ENV } from '../../core/config/env.token.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { RedisService } from '../../core/redis/redis.service.js';
import type { IdentityVerification } from '../../generated/prisma/client.js';
import { IdentityPurpose, IdentityStatus, Role } from '../../generated/prisma/enums.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { DiditClient } from './didit.client.js';
import { type DiditDecision, summarizeDecision, toIdentityStatus } from './didit.js';
import { DriverApprovalService } from './driver-approval.service.js';

/** New Didit sessions a user may start per day (declines and abandoned attempts), to protect the free quota. */
const MAX_SESSIONS_PER_DAY = 3;
const EVENT_TTL_S = 2 * 24 * 3600;
/** Didit document codes: drivers prove identity with their driving licence; riders may use any Indian ID. */
const DOC_TYPES: Record<IdentityPurpose, string[]> = { DRIVER: ['DL'], RIDER: ['ID', 'DL', 'P'] };

/** The user's identity check as the apps show it. */
export interface IdentityView {
  /** false = Didit isn't set up on this server (dev): nothing to do. */
  readonly isEnabled: boolean;
  readonly status: IdentityStatus;
  readonly verifiedAt: Date | null;
  readonly fullName: string | null;
  readonly documentType: string | null;
  readonly documentLast4: string | null;
  /** Why the last attempt was declined (short Didit reasons). */
  readonly reasons: string[];
}

/** A started session: the app opens Didit's in-app SDK with [sessionToken]. */
export interface StartedSession {
  readonly sessionId: string;
  readonly sessionToken: string;
}

/** Didit webhook body (session events). */
export interface DiditWebhook {
  readonly event_id?: string;
  readonly webhook_type?: string;
  readonly session_id?: string;
  readonly status?: string;
  readonly vendor_data?: string;
  readonly metadata?: { purpose?: string } | null;
  readonly decision?: DiditDecision;
}

/**
 * Identity checks with Didit: ID document + passive liveness + face match, inside the apps (native SDK).
 * Results arrive by signed webhook, and the apps also ask for a sync when the SDK closes.
 */
@Injectable()
export class KycService {
  private readonly logger = new Logger(KycService.name);

  constructor(
    @Inject(ENV) private readonly env: Env,
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly didit: DiditClient,
    private readonly approval: DriverApprovalService,
    private readonly notifier: NotifierService,
  ) {}

  async view(userId: string): Promise<IdentityView> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { identityStatus: true, identityVerifiedAt: true } });
    const latest = await this.latest(userId);
    const approved =
      user.identityStatus === IdentityStatus.APPROVED
        ? await this.prisma.identityVerification.findFirst({ where: { userId, status: IdentityStatus.APPROVED }, orderBy: { decidedAt: 'desc' } })
        : null;
    const shown = approved ?? latest;
    return {
      isEnabled: this.didit.isEnabled,
      status: user.identityStatus,
      verifiedAt: user.identityVerifiedAt,
      fullName: shown?.fullName ?? null,
      documentType: shown?.documentType ?? null,
      documentLast4: shown?.documentLast4 ?? null,
      reasons: latest?.status === IdentityStatus.DECLINED ? ((latest.warnings as string[] | null) ?? []) : [],
    };
  }

  /** Creates (or reuses) a Didit session for the caller. Drivers check their licence; riders any ID. */
  async start(user: AuthUser): Promise<StartedSession> {
    if (!this.didit.isEnabled) throw new ServiceUnavailableException('Identity checks are not set up yet');
    const purpose = user.role === Role.DRIVER ? IdentityPurpose.DRIVER : IdentityPurpose.RIDER;
    const workflowId = purpose === IdentityPurpose.DRIVER ? this.env.didit.driverWorkflowId : this.env.didit.riderWorkflowId;
    if (!workflowId) throw new ServiceUnavailableException('Identity checks are not set up yet');
    const me = await this.prisma.user.findUniqueOrThrow({ where: { id: user.userId }, select: { name: true, identityStatus: true } });
    if (me.identityStatus === IdentityStatus.APPROVED) throw new ConflictException('Your identity is already verified');
    if (me.identityStatus === IdentityStatus.IN_REVIEW) throw new ConflictException('Your verification is being reviewed');
    const [firstName, ...rest] = (me.name ?? '').trim().split(/\s+/).filter(Boolean);
    const session = await this.didit.createSession({
      workflowId,
      userId: user.userId,
      metadata: { purpose },
      expected: { firstName, lastName: rest.join(' ') || undefined, documentTypes: DOC_TYPES[purpose] },
    });
    const existing = await this.prisma.identityVerification.findUnique({ where: { sessionId: session.sessionId } });
    if (!existing) {
      const since = new Date(Date.now() - 24 * 3600 * 1000);
      const today = await this.prisma.identityVerification.count({ where: { userId: user.userId, createdAt: { gte: since } } });
      if (today >= MAX_SESSIONS_PER_DAY) {
        throw new HttpException('Too many attempts today. Please try again tomorrow', HttpStatus.TOO_MANY_REQUESTS);
      }
      await this.prisma.identityVerification.create({
        data: { userId: user.userId, purpose, sessionId: session.sessionId, providerStatus: session.status, status: toIdentityStatus(session.status) },
      });
    }
    return { sessionId: session.sessionId, sessionToken: session.sessionToken };
  }

  /** Called by the app when the SDK closes: fetches the decision so the result shows even without a webhook. */
  async sync(userId: string): Promise<IdentityView> {
    const latest = await this.latest(userId);
    if (!latest) throw new NotFoundException('No verification started');
    if (this.didit.isEnabled) {
      const decision = await this.didit.decision(latest.sessionId);
      await this.apply(latest, decision.status ?? latest.providerStatus, decision);
    }
    return this.view(userId);
  }

  /** A verified webhook. Idempotent on `event_id`; unknown sessions (e.g. made in the Didit console) are adopted. */
  async handleWebhook(body: DiditWebhook): Promise<void> {
    if (!body.session_id || !body.status) return;
    if (body.webhook_type !== 'status.updated' && body.webhook_type !== 'data.updated') return;
    if (body.event_id) {
      const isFirst = await this.redis.set(`kyc:event:${body.event_id}`, '1', 'EX', EVENT_TTL_S, 'NX');
      if (!isFirst) return;
    }
    let row = await this.prisma.identityVerification.findUnique({ where: { sessionId: body.session_id } });
    if (!row && body.vendor_data) {
      const user = await this.prisma.user.findUnique({ where: { id: body.vendor_data }, select: { id: true, role: true } });
      if (!user) return;
      const purpose = body.metadata?.purpose === IdentityPurpose.RIDER || user.role !== Role.DRIVER ? IdentityPurpose.RIDER : IdentityPurpose.DRIVER;
      row = await this.prisma.identityVerification.create({ data: { userId: user.id, purpose, sessionId: body.session_id } });
    }
    if (!row) return;
    // `data.updated` (a reviewer's edits) may come without a decision: fetch it.
    const decision = body.decision ?? (body.webhook_type === 'data.updated' ? await this.didit.decision(body.session_id) : undefined);
    await this.apply(row, body.status, decision);
  }

  private latest(userId: string): Promise<IdentityVerification | null> {
    return this.prisma.identityVerification.findFirst({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  /** Stores the result, mirrors it on the user (newest session wins; an approval always does) and re-checks the driver. */
  private async apply(row: IdentityVerification, providerStatus: string, decision?: DiditDecision): Promise<void> {
    const status = toIdentityStatus(providerStatus);
    const isDecided = status === IdentityStatus.APPROVED || status === IdentityStatus.DECLINED || status === IdentityStatus.IN_REVIEW;
    const summary = decision ? summarizeDecision(decision) : null;
    await this.prisma.identityVerification.update({
      where: { id: row.id },
      data: {
        status,
        providerStatus,
        ...(summary
          ? { documentType: summary.documentType, documentLast4: summary.documentLast4, fullName: summary.fullName, dateOfBirth: summary.dateOfBirth, warnings: summary.warnings }
          : {}),
        decidedAt: isDecided ? (row.decidedAt ?? new Date()) : null,
      },
    });
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: row.userId }, select: { identityStatus: true, driver: { select: { id: true } } } });
    const newest = await this.latest(row.userId);
    const isNewest = newest?.id === row.id;
    // Keep an approval unless this session is the newest one (Didit expired or overturned it).
    if (!isNewest && status !== IdentityStatus.APPROVED) return;
    if (user.identityStatus !== status) {
      await this.prisma.user.update({
        where: { id: row.userId },
        data: { identityStatus: status, identityVerifiedAt: status === IdentityStatus.APPROVED ? new Date() : null },
      });
      this.logger.log(`Identity ${row.sessionId} → ${providerStatus}`);
      void this.notifier.identityChanged({ userId: row.userId, purpose: row.purpose, status });
    }
    if (row.purpose === IdentityPurpose.DRIVER && user.driver) await this.approval.recompute(user.driver.id);
  }
}
