import { Body, Controller, ForbiddenException, HttpCode, Post } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import { Role } from '../../generated/prisma/enums.js';
import { LocationBatchDto, LocationDto } from '../drivers/dto/location.dto.js';
import { type IngestResult, LocationIngestService } from './location-ingest.service.js';

/** Driver GPS over HTTP, for when the socket is down (same processing as the socket events). */
@Controller()
@Roles(Role.DRIVER)
export class LocationsController {
  constructor(private readonly ingest: LocationIngestService) {}

  private static driverId(user: AuthUser): string {
    if (!user.driverId) throw new ForbiddenException('Register as a driver first');
    return user.driverId;
  }

  /** Heartbeat: keeps the dispatch index fresh while the socket is down. */
  @Post('drivers/me/location')
  @HttpCode(204)
  async location(@CurrentUser() user: AuthUser, @Body() body: LocationDto): Promise<void> {
    await this.ingest.live(LocationsController.driverId(user), body);
  }

  /** Fixes buffered on the phone while offline, oldest first; the newest becomes the live position. */
  @Post('drivers/me/locations')
  @HttpCode(200)
  locations(@CurrentUser() user: AuthUser, @Body() body: LocationBatchDto): Promise<IngestResult> {
    return this.ingest.batch(LocationsController.driverId(user), body.fixes);
  }
}
