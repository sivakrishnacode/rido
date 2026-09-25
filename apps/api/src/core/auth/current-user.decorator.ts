import { createParamDecorator, ExecutionContext } from '@nestjs/common';

import type { AuthUser } from './auth-user.js';

/** Injects the authenticated [AuthUser] into a controller method. */
export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthUser => ctx.switchToHttp().getRequest<{ user: AuthUser }>().user,
);
