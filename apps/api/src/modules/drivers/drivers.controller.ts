import { Body, Controller, ForbiddenException, Get, HttpCode, Param, ParseEnumPipe, Post } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import type { Driver, KycDocument } from '../../generated/prisma/client.js';
import { KycDocType, Role } from '../../generated/prisma/enums.js';
import { DriversService } from './drivers.service.js';
import { LocationDto } from './dto/location.dto.js';
import { RegisterDriverDto } from './dto/register-driver.dto.js';
import { ReviewDriverDto } from './dto/review-driver.dto.js';
import { UploadDocumentDto } from './dto/upload-document.dto.js';

/** D-04 … D-10, D-13 / D-14, admin KYC review. */
@Controller()
export class DriversController {
  constructor(private readonly drivers: DriversService) {}

  @Post('drivers')
  register(@CurrentUser() user: AuthUser, @Body() body: RegisterDriverDto): Promise<{ driver: Driver; accessToken: string }> {
    return this.drivers.register(user.userId, body);
  }

  @Roles(Role.DRIVER)
  @Get('drivers/me')
  me(@CurrentUser() user: AuthUser): Promise<Driver> {
    return this.drivers.me(DriversController.driverId(user));
  }

  @Roles(Role.DRIVER)
  @Get('drivers/me/documents')
  documents(@CurrentUser() user: AuthUser): Promise<KycDocument[]> {
    return this.drivers.documents(DriversController.driverId(user));
  }

  @Roles(Role.DRIVER)
  @Post('drivers/me/documents/:type')
  upload(
    @CurrentUser() user: AuthUser,
    @Param('type', new ParseEnumPipe(KycDocType)) type: KycDocType,
    @Body() body: UploadDocumentDto,
  ): Promise<KycDocument> {
    return this.drivers.uploadDocument({ driverId: DriversController.driverId(user), type, fileUrl: body.fileUrl });
  }

  @Roles(Role.DRIVER)
  @Post('drivers/me/online')
  @HttpCode(200)
  online(@CurrentUser() user: AuthUser, @Body() body: LocationDto): Promise<Driver> {
    return this.drivers.goOnline({ driverId: DriversController.driverId(user), ...body });
  }

  @Roles(Role.DRIVER)
  @Post('drivers/me/offline')
  @HttpCode(200)
  offline(@CurrentUser() user: AuthUser): Promise<Driver> {
    return this.drivers.goOffline(DriversController.driverId(user));
  }

  @Roles(Role.DRIVER)
  @Post('drivers/me/location')
  @HttpCode(204)
  location(@CurrentUser() user: AuthUser, @Body() body: LocationDto): Promise<void> {
    return this.drivers.heartbeat({ driverId: DriversController.driverId(user), ...body });
  }

  @Roles(Role.ADMIN)
  @Post('admin/drivers/:id/review')
  @HttpCode(200)
  review(@Param('id') id: string, @Body() body: ReviewDriverDto): Promise<Driver> {
    return this.drivers.review({ driverId: id, ...body });
  }

  private static driverId(user: AuthUser): string {
    if (!user.driverId) throw new ForbiddenException('Register as a driver first');
    return user.driverId;
  }
}
