import { Body, Controller, ForbiddenException, Get, HttpCode, Param, ParseEnumPipe, Patch, Post, Query, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import { MAX_UPLOAD_BYTES, type UploadedBlob } from '../../core/storage/file-storage.service.js';
import type { Driver, KycDocument } from '../../generated/prisma/client.js';
import { KycDocType, Role } from '../../generated/prisma/enums.js';
import { DriverEarningsService, type Earnings } from './driver-earnings.service.js';
import { DriversService } from './drivers.service.js';
import { EarningsQueryDto } from './dto/earnings-query.dto.js';
import { LocationDto } from './dto/location.dto.js';
import { RegisterDriverDto } from './dto/register-driver.dto.js';
import { ReviewDriverDto } from './dto/review-driver.dto.js';
import { UpdateDriverDto } from './dto/update-driver.dto.js';

/** D-04 … D-10, D-13 / D-14, admin KYC review. */
@Controller()
export class DriversController {
  constructor(
    private readonly drivers: DriversService,
    private readonly earningsService: DriverEarningsService,
  ) {}

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
  @Patch('drivers/me')
  update(@CurrentUser() user: AuthUser, @Body() body: UpdateDriverDto): Promise<Driver> {
    return this.drivers.update(DriversController.driverId(user), body);
  }

  /** D-23: ?period=today|week|month. */
  @Roles(Role.DRIVER)
  @Get('drivers/me/earnings')
  earnings(@CurrentUser() user: AuthUser, @Query() q: EarningsQueryDto): Promise<Earnings> {
    return this.earningsService.summary(DriversController.driverId(user), q.period ?? 'today');
  }

  @Roles(Role.DRIVER)
  @Get('drivers/me/documents')
  documents(@CurrentUser() user: AuthUser): Promise<KycDocument[]> {
    return this.drivers.documents(DriversController.driverId(user));
  }

  /** D-08: multipart/form-data with a `file` field (JPG, PNG, WebP or PDF, ≤ 8 MB). */
  @Roles(Role.DRIVER)
  @Post('drivers/me/documents/:type')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES } }))
  upload(
    @CurrentUser() user: AuthUser,
    @Param('type', new ParseEnumPipe(KycDocType)) type: KycDocType,
    @UploadedFile() file?: UploadedBlob,
  ): Promise<KycDocument> {
    return this.drivers.uploadDocument({ driverId: DriversController.driverId(user), type, file });
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
