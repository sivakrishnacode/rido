import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';

import type { AuthUser, JwtPayload } from './auth-user.js';
import { IS_PUBLIC_KEY } from './public.decorator.js';
import { UserAccessService } from './user-access.service.js';

/**
 * Global guard: every HTTP route needs a valid Bearer JWT unless marked `@Public()`. The caller's role and driver
 * profile are the account's current ones ([UserAccessService]), not the token's, so role changes and blocks apply at
 * once.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
    private readonly access: UserAccessService,
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
    // Blocked by an admin (a Redis flag set by AdminUsersService) → 403; deleted account → 401.
    req.user = await this.access.resolve(payload);
    return true;
  }
}
