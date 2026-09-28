import { Body, Controller, Get, HttpCode, Param, Post, Req } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Public } from '../../core/auth/public.decorator.js';
import { SafetyCheckDto } from './dto/safety-check.dto.js';
import { SosDto } from './dto/sos.dto.js';
import { clientIp } from './rate-limit.js';
import { type SosResult, SosService } from './sos.service.js';
import { type ShareLink, ShareService, type ShareView } from './share.service.js';

type Req = { headers: Record<string, string | string[] | undefined>; ip?: string };

/** Trip safety for the apps: SOS, live share links (and the public read behind the tracking page). */
@Controller()
export class SafetyController {
  constructor(
    private readonly share: ShareService,
    private readonly sos: SosService,
  ) {}

  /**
   * SOS from the trip's passenger or driver, with the phone's position: recorded, pushed to admins, and answered with
   * a live share link to text to emergency contacts. A repeat within 2 min returns the same SOS.
   */
  @Post('trips/:id/sos')
  @HttpCode(200)
  raiseSos(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() body: SosDto): Promise<SosResult> {
    return this.sos.create(user, id, body);
  }

  /** Passenger: "I'm OK" / "Get help" to a safety check push (long stop, route change, night arrival). HELP → SOS. */
  @Post('trips/:id/safety-check')
  @HttpCode(200)
  answerCheck(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() body: SafetyCheckDto): ReturnType<SosService['answerCheck']> {
    return this.sos.answerCheck(user, id, body);
  }

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
