import { Controller, Get, HttpCode, Param, Post, Req } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Public } from '../../core/auth/public.decorator.js';
import { clientIp } from './rate-limit.js';
import { type ShareLink, ShareService, type ShareView } from './share.service.js';

type Req = { headers: Record<string, string | string[] | undefined>; ip?: string };

/** Trip safety for the apps: live share links (and the public read behind the tracking page). */
@Controller()
export class SafetyController {
  constructor(private readonly share: ShareService) {}

  /** Passenger: a signed live-tracking link to send to someone (valid until 30 min after the trip ends). */
  @Post('trips/:id/share')
  @HttpCode(200)
  shareLink(@CurrentUser() user: AuthUser, @Param('id') id: string): Promise<ShareLink> {
    return this.share.create(user, id);
  }

  /** Public (no sign-in, rate limited): what the link shows. 404 bad link, 410 expired. */
  @Public()
  @Get('share/:token')
  view(@Param('token') token: string, @Req() req: Req): Promise<ShareView> {
    return this.share.view(token, clientIp(req));
  }
}
