import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { Role } from '../../generated/prisma/enums.js';
import type { AuthUser } from '../auth/auth-user.js';
import { RedisService } from '../redis/redis.service.js';
import { clientIp, type IpRequest, isFromSelf } from './client-ip.js';
import { rateLimit } from './rate-limit.js';
import { RATE_LIMIT_KEY, type RateLimitRule } from './rate-limit.decorator.js';

/** The counter a request counts against: the user when signed in, else the client IP; null = not limited. */
export function limitSubject(req: IpRequest & { user?: AuthUser }): string | null {
  // Admin tools (map search, hotspot names for a whole table) are trusted and may call in bursts.
  if (req.user?.role === Role.ADMIN) return null;
  if (req.user) return `u:${req.user.userId}`;
  return isFromSelf(req) ? null : `ip:${clientIp(req)}`;
}

/**
 * Global guard (after [JwtAuthGuard], so `req.user` is set): enforces `@RateLimit(...)` with a fixed window in Redis.
 * Over the limit → 429 [RATE_LIMIT_MESSAGE] with Retry-After.
 */
@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly redis: RedisService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    if (ctx.getType() !== 'http') return true;
    const rule = this.reflector.getAllAndOverride<RateLimitRule | undefined>(RATE_LIMIT_KEY, [ctx.getHandler(), ctx.getClass()]);
    if (!rule) return true;
    const who = limitSubject(ctx.switchToHttp().getRequest<IpRequest & { user?: AuthUser }>());
    if (who) await rateLimit(this.redis, `${rule.name}:${who}`, rule.limit, rule.windowS);
    return true;
  }
}
