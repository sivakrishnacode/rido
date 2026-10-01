import { Body, Controller, ForbiddenException, Get, HttpCode, Param, ParseEnumPipe, Patch, Post, Put, Query, Res, StreamableFile, UploadedFile, UseInterceptors } from '@nestjs/common';
import type { Response } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import { FileStorageService, MAX_UPLOAD_BYTES, type UploadedBlob } from '../../core/storage/file-storage.service.js';
import type { Driver, KycDocument } from '../../generated/prisma/client.js';
import { KycDocType, Role } from '../../generated/prisma/enums.js';
import type { BookingPrefs } from './booking-prefs.js';
import { DriverEarningsService, type Earnings } from './driver-earnings.service.js';
import { DriversService } from './drivers.service.js';
import { AuditInterceptor } from '../admin/audit.interceptor.js';
import { BookingPrefsDto } from './dto/booking-prefs.dto.js';
import { EarningsQueryDto } from './dto/earnings-query.dto.js';
import { LocationDto } from './dto/location.dto.js';
import { RegisterDriverDto } from './dto/register-driver.dto.js';
import { ReviewDriverDto } from './dto/review-driver.dto.js';
import { ReviewPhotoDto } from './dto/review-photo.dto.js';
import { UpdateDriverDto } from './dto/update-driver.dto.js';

/** D-04 … D-10, D-13 / D-14, admin KYC review. */
@Controller()
export class DriversController {
  constructor(
    private readonly drivers: DriversService,
    private readonly earningsService: DriverEarningsService,
    private readonly files: FileStorageService,
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

  /** Booking preferences: pickup distance, trip length, go-to destination (dispatch only offers trips that fit). */
  @Roles(Role.DRIVER)
  @Get('drivers/me/booking-preferences')
  bookingPrefs(@CurrentUser() user: AuthUser): Promise<BookingPrefs> {
    return this.drivers.bookingPrefs(DriversController.driverId(user));
  }

  @Roles(Role.DRIVER)
  @Put('drivers/me/booking-preferences')
  setBookingPrefs(@CurrentUser() user: AuthUser, @Body() body: BookingPrefsDto): Promise<BookingPrefs> {
    return this.drivers.setBookingPrefs(DriversController.driverId(user), body);
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

  /** D-07 profile photo: multipart `file` (JPG / PNG / WebP ≤ 8 MB), matched to the verified selfie. */
  @Roles(Role.DRIVER)
  @Post('drivers/me/photo')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES } }))
  uploadPhoto(@CurrentUser() user: AuthUser, @UploadedFile() file?: UploadedBlob): Promise<{ status: 'APPROVED' | 'IN_REVIEW' }> {
    return this.drivers.uploadPhoto({ driverId: DriversController.driverId(user), file });
  }

  @Roles(Role.ADMIN)
  @Post('admin/drivers/:id/photo')
  @HttpCode(200)
  @UseInterceptors(AuditInterceptor)
  reviewPhoto(@Param('id') id: string, @Body() body: ReviewPhotoDto): Promise<Driver> {
    return this.drivers.reviewPhoto({ driverId: id, ...body });
  }

  /** The driver's profile photo (`?v=` = photo file, for caching). The driver, admins and their riders only. */
  @Get('drivers/:id/photo')
  async photo(@CurrentUser() user: AuthUser, @Param('id') id: string, @Res({ passthrough: true }) res: Response): Promise<StreamableFile> {
    const name = await this.drivers.photo({ driverId: id, viewer: user });
    const f = await this.files.open(name);
    res.setHeader('cache-control', 'private, max-age=86400');
    return new StreamableFile(f.stream, { type: f.type, length: f.size || undefined, disposition: 'inline' });
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
