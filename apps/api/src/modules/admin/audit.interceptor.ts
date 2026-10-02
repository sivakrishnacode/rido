import { CallHandler, ExecutionContext, Injectable, Logger, NestInterceptor } from '@nestjs/common';
import { concatMap, Observable } from 'rxjs';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Prisma } from '../../generated/prisma/client.js';

interface Req {
  readonly method: string;
  readonly route?: { path: string };
  readonly params: Record<string, string>;
  readonly body: unknown;
  readonly user?: AuthUser;
}

/**
 * Records every successful admin change (POST/PUT/PATCH/DELETE) in AuditLog, before the answer goes out (a write
 * left to run after it could be read back missing). A failed audit write is logged, never fails the change.
 */
@Injectable()
export class AuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AuditInterceptor.name);

  constructor(private readonly prisma: PrismaService) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = ctx.switchToHttp().getRequest<Req>();
    if (req.method === 'GET' || !req.user) return next.handle();
    const path = req.route?.path ?? '';
    const entity = path.replace(/^\/?v1\/admin\//, '').split('/')[0] ?? 'admin';
    const entityId = req.params.id ?? null;
    return next.handle().pipe(
      concatMap(async (result: unknown) => {
        await this.prisma.auditLog
          .create({
            data: {
              actorId: req.user!.userId,
              action: `${req.method} ${path}`,
              entity,
              entityId,
              data: { params: req.params, body: AuditInterceptor.trim(req.body) } as Prisma.InputJsonValue,
            },
          })
          .catch((e: Error) => this.logger.warn(`Audit write failed: ${e.message}`));
        return result;
      }),
    );
  }

  /** Keeps audit rows small (e.g. drops huge cell arrays to a count). */
  private static trim(body: unknown): unknown {
    if (!body || typeof body !== 'object') return body ?? null;
    return Object.fromEntries(
      Object.entries(body as Record<string, unknown>).map(([k, v]) => [k, Array.isArray(v) && v.length > 20 ? `[${v.length} items]` : v]),
    );
  }
}
