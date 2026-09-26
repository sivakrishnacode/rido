import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';

import { RedisService } from '../redis/redis.service.js';
import type { AuthUser, JwtPayload } from './auth-user.js';
import { IS_PUBLIC_KEY } from './public.decorator.js';

/** Global guard: every HTTP route needs a valid Bearer JWT unless marked `@Public()`. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
    private readonly redis: RedisService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    // Socket.IO messages are authenticated once, on connect (RealtimeGateway.handleConnection).
    if (ctx.getType() !== 'http') return true;
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [ctx.getHandler(), ctx.getClass()]);
    if (isPublic) return true;
    const req = ctx.switchToHttp().getRequest<{ headers: Record<string, string | undefined>; user?: AuthUser }>();
    const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
    if (!token) throw new UnauthorizedException('Missing access token');
    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(token);
    } catch {
      throw new UnauthorizedException('Invalid or expired access token');
    }
    // Blocked by an admin (set in Redis by AdminUsersService).
    if (await this.redis.exists(`user:blocked:${payload.sub}`)) throw new ForbiddenException('Your account is blocked. Contact support.');
    req.user = { userId: payload.sub, role: payload.role, driverId: payload.driverId };
    return true;
  }
}
