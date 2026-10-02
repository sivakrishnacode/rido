import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { FileStorageService, type UploadedBlob } from '../../core/storage/file-storage.service.js';
import { Role, TripKind, TripStatus } from '../../generated/prisma/enums.js';

/** Which photo of a parcel trip: the sender's photo of the parcel, or the driver's proof of delivery. */
export type TripPhotoKind = 'parcel' | 'delivery';

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
/** The sender may add (or replace) the parcel photo until the driver picks it up. */
const BEFORE_PICKUP: TripStatus[] = [TripStatus.SCHEDULED, TripStatus.SEARCHING, TripStatus.DRIVER_ASSIGNED, TripStatus.DRIVER_ARRIVED];
/** The driver takes the delivery photo at the drop: while carrying it, or just after marking it delivered. */
const AT_DELIVERY: TripStatus[] = [TripStatus.PICKED_UP, TripStatus.DELIVERED];

/**
 * Photos on parcel trips (stored like KYC files, private): the sender's photo of the parcel before pickup
 * (Trip.parcelPhotoFile) and the driver's proof of delivery (Trip.deliveryPhotoFile). Both are in the trip JSON;
 * the images are served to the passenger, the trip's driver and admins only (others get 404).
 */
@Injectable()
export class TripPhotosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly files: FileStorageService,
  ) {}

  /** POST /trips/:id/parcel-photo: the passenger (sender) of a parcel trip, before pickup. */
  async addParcelPhoto(user: AuthUser, tripId: string, file?: UploadedBlob): Promise<{ ok: true }> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId }, select: { passengerId: true, kind: true, status: true } });
    if (!trip || trip.passengerId !== user.userId) throw new NotFoundException('Trip not found');
    if (trip.kind !== TripKind.PARCEL) throw new BadRequestException('Only a parcel has a parcel photo');
    if (!BEFORE_PICKUP.includes(trip.status)) throw new ConflictException('The parcel has already been picked up');
    const parcelPhotoFile = await this.files.save(TripPhotosService.image(file));
    // Guarded on the status: a pickup at the same moment wins.
    const { count } = await this.prisma.trip.updateMany({ where: { id: tripId, status: { in: BEFORE_PICKUP } }, data: { parcelPhotoFile } });
    if (count === 0) throw new ConflictException('The parcel has already been picked up');
    return { ok: true };
  }

  /** POST /trips/:id/delivery-photo: the trip's driver, once the parcel is picked up (or just delivered). */
  async addDeliveryPhoto(user: AuthUser, tripId: string, file?: UploadedBlob): Promise<{ ok: true }> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId }, select: { driverId: true, status: true } });
    if (!trip || !user.driverId || trip.driverId !== user.driverId) throw new NotFoundException('Trip not found');
    if (!AT_DELIVERY.includes(trip.status)) throw new ConflictException('Take the delivery photo at the drop, after pickup');
    const deliveryPhotoFile = await this.files.save(TripPhotosService.image(file));
    await this.prisma.trip.update({ where: { id: tripId }, data: { deliveryPhotoFile } });
    return { ok: true };
  }

  /** The stored file of a trip photo, for the passenger, the trip's driver and admins; 404 for anyone else or none. */
  async photo(user: AuthUser, tripId: string, kind: TripPhotoKind): Promise<string> {
    const trip = await this.prisma.trip.findUnique({
      where: { id: tripId },
      select: { passengerId: true, driverId: true, parcelPhotoFile: true, deliveryPhotoFile: true },
    });
    const canSee = !!trip && (user.role === Role.ADMIN || trip.passengerId === user.userId || (!!user.driverId && trip.driverId === user.driverId));
    const file = canSee ? (kind === 'parcel' ? trip.parcelPhotoFile : trip.deliveryPhotoFile) : null;
    if (!file) throw new NotFoundException('No photo');
    return file;
  }

  private static image(file?: UploadedBlob): UploadedBlob {
    if (!file?.buffer?.length || !IMAGE_TYPES.includes(file.mimetype)) throw new BadRequestException('Attach a photo (JPG, PNG or WebP)');
    return file;
  }
}
