import { Controller, Get, HttpCode, Param, Post, Res, StreamableFile, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { CurrentUser } from '../../core/auth/current-user.decorator.js';
import { Roles } from '../../core/auth/roles.decorator.js';
import { FileStorageService, MAX_UPLOAD_BYTES, type UploadedBlob } from '../../core/storage/file-storage.service.js';
import { Role } from '../../generated/prisma/enums.js';
import { type TripPhotoKind, TripPhotosService } from './trip-photos.service.js';

/** Parcel photo (sender, before pickup) and delivery proof (driver, at the drop): multipart `file`, JPG/PNG/WebP ≤ 8 MB. */
@Controller('trips')
export class TripPhotosController {
  constructor(
    private readonly photos: TripPhotosService,
    private readonly files: FileStorageService,
  ) {}

  @Post(':id/parcel-photo')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES } }))
  addParcelPhoto(@CurrentUser() user: AuthUser, @Param('id') id: string, @UploadedFile() file?: UploadedBlob): Promise<{ ok: true }> {
    return this.photos.addParcelPhoto(user, id, file);
  }

  @Roles(Role.DRIVER)
  @Post(':id/delivery-photo')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES } }))
  addDeliveryPhoto(@CurrentUser() user: AuthUser, @Param('id') id: string, @UploadedFile() file?: UploadedBlob): Promise<{ ok: true }> {
    return this.photos.addDeliveryPhoto(user, id, file);
  }

  /** The image: the passenger, the trip's driver and admins only. */
  @Get(':id/parcel-photo')
  parcelPhoto(@CurrentUser() user: AuthUser, @Param('id') id: string, @Res({ passthrough: true }) res: Response): Promise<StreamableFile> {
    return this.stream(user, id, 'parcel', res);
  }

  @Get(':id/delivery-photo')
  deliveryPhoto(@CurrentUser() user: AuthUser, @Param('id') id: string, @Res({ passthrough: true }) res: Response): Promise<StreamableFile> {
    return this.stream(user, id, 'delivery', res);
  }

  private async stream(user: AuthUser, tripId: string, kind: TripPhotoKind, res: Response): Promise<StreamableFile> {
    const f = await this.files.open(await this.photos.photo(user, tripId, kind));
    res.setHeader('cache-control', 'private, max-age=86400');
    res.setHeader('x-content-type-options', 'nosniff');
    return new StreamableFile(f.stream, { type: f.type, length: f.size || undefined, disposition: 'inline' });
  }
}
