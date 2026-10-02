import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { FileStorageService, type UploadedBlob } from '../../core/storage/file-storage.service.js';
import { DriverEarningsService } from './driver-earnings.service.js';
import type { UpdateDriverDto } from './dto/update-driver.dto.js';
import type { BookingPrefsDto } from './dto/booking-prefs.dto.js';
import { type Area, type BookingPrefs, DEFAULT_HELPERS, type GoTo, GO_TO_HOURS, readPrefs, type StayIn, STAY_IN_HOURS } from './booking-prefs.js';
import { isGoodsTruck } from '../fares/goods-modes.js';

import { DriverStateCache } from '../../core/driver-state/driver-state.cache.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Driver, KycDocument, Prisma } from '../../generated/prisma/client.js';
import { DriverStatus, Gender, IdentityStatus, KycDocType, KycStatus, Role, TripStatus, type VehicleKind } from '../../generated/prisma/enums.js';
import { AuthService } from '../auth/auth.service.js';
import { SubscriptionsService } from '../subscriptions/subscriptions.service.js';
import { nearbyVehicles, type NearbyVehicle } from './nearby-vehicles.js';
import { DriverLocationService } from './driver-location.service.js';
import type { RegisterDriverDto } from './dto/register-driver.dto.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { DriverApprovalService } from '../kyc/driver-approval.service.js';
import { DiditClient } from '../kyc/didit.client.js';
import { REQUIRED_DOCS } from '../kyc/driver-approval.js';

/** Driver registration, KYC and online status. */
@Injectable()
export class DriversService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly subs: SubscriptionsService,
    private readonly location: DriverLocationService,
    private readonly earnings: DriverEarningsService,
    private readonly files: FileStorageService,
    private readonly notifier: NotifierService,
    private readonly approval: DriverApprovalService,
    private readonly didit: DiditClient,
    private readonly state: DriverStateCache,
  ) {}

  /** Free vehicles around [at] for the rider's map (nearby-vehicles.ts). */
  async nearbyVehicles(at: { lat: number; lng: number }, kinds: readonly VehicleKind[]): Promise<{ vehicles: NearbyVehicle[] }> {
    return { vehicles: await nearbyVehicles(this.location, at, kinds) };
  }

  /** Creates the driver, the RC + insurance rows and a 30-day free trial; returns a token with the DRIVER role. */
  async register(userId: string, dto: RegisterDriverDto): Promise<{ driver: Driver; accessToken: string }> {
    const { name, gender, ...vehicle } = dto;
    const driver = await this.prisma.$transaction(async (tx) => {
      await tx.user.update({ where: { id: userId }, data: { name, gender, role: Role.DRIVER } });
      return tx.driver.create({
        data: {
          ...vehicle,
          plate: vehicle.plate.toUpperCase(),
          userId,
          documents: { create: REQUIRED_DOCS.map((type) => ({ type })) },
        },
      });
    });
    await this.subs.startTrial(driver.id, driver.vehicleKind);
    const accessToken = await this.auth.issueToken({ sub: userId, role: Role.DRIVER, driverId: driver.id });
    return { driver, accessToken };
  }

  me(driverId: string): Promise<Driver> {
    return this.prisma.driver.findUniqueOrThrow({ where: { id: driverId }, include: { user: true } });
  }

  /** The documents still uploaded by hand (RC, insurance). Older rows (licence, Aadhaar, police) are hidden. */
  documents(driverId: string): Promise<KycDocument[]> {
    return this.prisma.kycDocument.findMany({ where: { driverId, type: { in: [...REQUIRED_DOCS] } }, orderBy: { type: 'asc' } });
  }

  /** Profile edits (D-25). Name and gender live on the user; the rest on the driver. */
  async update(driverId: string, dto: UpdateDriverDto): Promise<Driver> {
    const { name, gender, ...vehicle } = dto;
    if (gender) {
      // Gender decides who gets Butterfly (women-only) rides: set at sign-up, then changed only by support.
      const current = await this.prisma.driver.findUniqueOrThrow({ where: { id: driverId }, select: { status: true, user: { select: { gender: true } } } });
      // None stored reads as "prefer not to say" in the app, which sends that back on every profile save.
      const stored = current.user.gender ?? Gender.PREFER_NOT_TO_SAY;
      if (stored !== gender && current.status !== DriverStatus.PENDING) {
        throw new ForbiddenException('Contact support to change your gender');
      }
    }
    const driver = await this.prisma.driver.update({
      where: { id: driverId },
      data: { ...vehicle, plate: vehicle.plate?.toUpperCase(), ...(name || gender ? { user: { update: { name, gender } } } : {}) },
    });
    await this.state.invalidate(driver.id);
    return this.me(driver.id);
  }

  async bookingPrefs(driverId: string): Promise<BookingPrefs> {
    const d = await this.prisma.driver.findUniqueOrThrow({ where: { id: driverId }, select: { bookingPrefs: true } });
    return readPrefs(d.bookingPrefs, new Date());
  }

  /**
   * Replaces the preferences. A go-to switches itself off after [GO_TO_HOURS], a stay-in after [STAY_IN_HOURS]; one
   * of the two at a time (turning one on turns off the other one stored).
   */
  async setBookingPrefs(driverId: string, dto: BookingPrefsDto): Promise<BookingPrefs> {
    if (dto.minTripKm && dto.maxTripKm && dto.minTripKm > dto.maxTripKm) {
      throw new BadRequestException('Shortest trip must be less than the longest trip');
    }
    if (dto.goTo && dto.stayIn) throw new BadRequestException('Turn off Go To to use Stay In');
    if (dto.shifting) {
      const { vehicleKind } = await this.prisma.driver.findUniqueOrThrow({ where: { id: driverId }, select: { vehicleKind: true } });
      if (!isGoodsTruck(vehicleKind)) throw new BadRequestException('Packers & Movers jobs are for three-wheeler, mini truck, pickup and truck drivers');
    }
    const now = new Date();
    const current = await this.bookingPrefs(driverId);
    const until = (hours: number): string => new Date(now.getTime() + hours * 3_600_000).toISOString();
    const place = (a: Area): Area => ({ name: a.name, lat: a.lat, lng: a.lng });
    const same = (a: Area, b: Area): boolean => a.lat === b.lat && a.lng === b.lng;
    // A go-to / stay-in already running stays as it is when the app sends the same place back (its timer goes on).
    let goTo: GoTo | null = null;
    if (dto.goTo) goTo = current.goTo && same(current.goTo, dto.goTo) ? current.goTo : { ...place(dto.goTo), until: until(GO_TO_HOURS) };
    let stayIn: StayIn | null = null;
    if (dto.stayIn) {
      const kept = current.stayIn && same(current.stayIn, dto.stayIn) && current.stayIn.radiusKm === dto.stayIn.radiusKm;
      stayIn = kept ? current.stayIn! : { ...place(dto.stayIn), radiusKm: dto.stayIn.radiusKm, until: until(STAY_IN_HOURS) };
    } else if (dto.stayIn === undefined && !goTo) {
      // Not sent (an older app): the stored one stays, unless this save turns a go-to on.
      stayIn = current.stayIn ?? null;
    }
    const prefs: BookingPrefs = {
      maxPickupKm: dto.maxPickupKm ?? null,
      minTripKm: dto.minTripKm ?? null,
      maxTripKm: dto.maxTripKm ?? null,
      goTo,
      stayIn,
      parcels: dto.parcels ?? current.parcels ?? true,
      areas: dto.areas === undefined ? (current.areas ?? []) : (dto.areas ?? []).map(place),
      // Not sent (an older app): what is stored stays.
      shifting: dto.shifting ?? current.shifting ?? false,
      helpers: dto.helpers ?? current.helpers ?? DEFAULT_HELPERS,
    };
    await this.prisma.driver.update({ where: { id: driverId }, data: { bookingPrefs: prefs as Prisma.InputJsonValue } });
    return prefs;
  }

  /** Stores the photo / PDF and puts the document under review. `fileUrl` holds the stored file name. */
  async uploadDocument(params: { driverId: string; type: KycDocType; file?: UploadedBlob }): Promise<KycDocument> {
    if (!REQUIRED_DOCS.includes(params.type)) throw new BadRequestException('This document is checked in the identity step');
    const fileUrl = await this.files.save(params.file);
    const data = { status: KycStatus.UNDER_REVIEW, fileUrl, rejectReason: null };
    const doc = await this.prisma.kycDocument.upsert({
      where: { driverId_type: { driverId: params.driverId, type: params.type } },
      create: { driverId: params.driverId, type: params.type, ...data },
      update: data,
    });
    await this.approval.recompute(params.driverId);
    return doc;
  }

  async goOnline(params: { driverId: string; lat: number; lng: number }): Promise<Driver> {
    const driver = await this.prisma.driver.findUniqueOrThrow({ where: { id: params.driverId } });
    if (driver.status !== DriverStatus.APPROVED) throw new ForbiddenException(`Account is ${driver.status.toLowerCase()}`);
    // Paused for too many cancellations (trips/driver-blocks.service.ts).
    if (driver.blockedUntil && driver.blockedUntil.getTime() > Date.now()) {
      const until = driver.blockedUntil.toISOString();
      throw new ForbiddenException({
        code: 'DRIVER_TEMP_BLOCKED',
        message: `You cancelled too many rides, so you can't go online until ${driver.blockedUntil.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', hour: 'numeric', minute: '2-digit', hour12: true, day: 'numeric', month: 'short' })}`,
        details: { until },
      });
    }
    if (!(await this.subs.canGoOnline(driver.id))) throw new ForbiddenException('Plan expired. Renew to go online again');
    // Riders see the driver's photo (the verified selfie), so it is required once identity checks are on.
    if (this.didit.isEnabled && !driver.photoFile) {
      throw new ForbiddenException({
        message: driver.pendingPhotoFile
          ? "Your profile photo is being checked. You can go online once it's approved"
          : 'Add your profile photo first: Account › Documents',
        code: 'PHOTO_REQUIRED',
      });
    }
    await this.freeIfStale(driver.id);
    await this.location.update({ driverId: driver.id, kind: driver.vehicleKind, lat: params.lat, lng: params.lng });
    await this.earnings.sessionStarted(driver.id);
    // Only a real offline → online (the app repeats this call on resume): keeps the driver's wait for the idle bonus.
    if (!driver.isOnline) await this.location.markOnline(driver.id);
    const online = await this.prisma.driver.update({ where: { id: driver.id }, data: { isOnline: true }, include: { user: { select: { isBlocked: true } } } });
    await this.state.set(driver.id, { isOnline: true, vehicleKind: online.vehicleKind, isBlocked: online.user.isBlocked });
    return online;
  }

  /**
   * D-07 profile photo (riders see it). With Didit on, it must be the verified person: the photo is matched
   * against the live selfie of the approved identity check. A clear match goes live at once; no face or several
   * faces → 422 (retake); a low score or Didit unreachable → waits for an admin.
   */
  async uploadPhoto(params: { driverId: string; file?: UploadedBlob }): Promise<{ status: 'APPROVED' | 'IN_REVIEW' }> {
    if (!params.file || !['image/jpeg', 'image/png', 'image/webp'].includes(params.file.mimetype)) {
      throw new BadRequestException('Take a photo (JPG, PNG or WebP)');
    }
    const driver = await this.prisma.driver.findUniqueOrThrow({
      where: { id: params.driverId },
      select: { id: true, userId: true, selfieFile: true, user: { select: { identityStatus: true } } },
    });
    const live = async (photoFile: string, score: number | null): Promise<{ status: 'APPROVED' }> => {
      await this.prisma.driver.update({
        where: { id: driver.id },
        data: { photoFile, photoUpdatedAt: new Date(), pendingPhotoFile: null, photoMatchScore: score, photoRejectReason: null },
      });
      return { status: 'APPROVED' };
    };
    if (!this.didit.isEnabled) return live(await this.files.save(params.file), null);
    if (driver.user.identityStatus !== IdentityStatus.APPROVED) {
      throw new ConflictException('Verify your licence, Aadhaar and selfie first');
    }
    const name = await this.files.save(params.file);
    const review = async (score: number | null): Promise<{ status: 'IN_REVIEW' }> => {
      await this.prisma.driver.update({ where: { id: driver.id }, data: { pendingPhotoFile: name, photoMatchScore: score, photoRejectReason: null } });
      void this.notifier.photoSubmitted(driver.id);
      return { status: 'IN_REVIEW' };
    };
    if (!driver.selfieFile) return review(null);
    let match: { score: number | null; faces: number; isMatch: boolean };
    try {
      match = await this.didit.faceMatch({
        photo: { buffer: params.file.buffer, type: params.file.mimetype },
        reference: await this.files.read(driver.selfieFile),
        vendorData: driver.userId,
      });
    } catch {
      return review(null);
    }
    if (match.faces !== 1) {
      throw new UnprocessableEntityException(
        match.faces === 0 ? "We couldn't find your face. Retake it facing the camera in good light" : 'Only you should be in the photo. Retake it alone',
      );
    }
    return match.isMatch ? live(name, match.score) : review(match.score);
  }

  /** Admin decision on a photo that waits for review (low face-match score). */
  async reviewPhoto(params: { driverId: string; isApproved: boolean; reason?: string }): Promise<Driver> {
    const driver = await this.prisma.driver.findUniqueOrThrow({ where: { id: params.driverId } });
    if (!driver.pendingPhotoFile) throw new BadRequestException('No photo is waiting for review');
    const reason = params.reason?.trim() || 'Please take a clear photo of your face';
    const updated = await this.prisma.driver.update({
      where: { id: driver.id },
      data: params.isApproved
        ? { photoFile: driver.pendingPhotoFile, photoUpdatedAt: new Date(), pendingPhotoFile: null, photoRejectReason: null }
        : { pendingPhotoFile: null, photoRejectReason: reason },
    });
    void this.notifier.photoReviewed({ driverId: driver.id, isApproved: params.isApproved, reason });
    return updated;
  }

  /**
   * The driver's photo, for the driver, admins, and riders who have (or had) a trip with them. Others get 404,
   * so photos can't be browsed by id.
   */
  async photo(params: { driverId: string; viewer: { userId: string; role: Role; driverId?: string } }): Promise<string> {
    const { viewer } = params;
    const driverId = params.driverId === 'me' ? (viewer.driverId ?? '') : params.driverId;
    const driver = await this.prisma.driver.findUnique({ where: { id: driverId }, select: { photoFile: true } });
    if (!driver?.photoFile) throw new NotFoundException('No photo');
    const canSee =
      viewer.role === Role.ADMIN ||
      viewer.driverId === driverId ||
      (await this.prisma.trip.count({ where: { driverId, passengerId: viewer.userId } })) > 0;
    if (!canSee) throw new NotFoundException('No photo');
    return driver.photoFile;
  }

  /** A busy flag left over from a trip that has ended (or isn't theirs) would hide the driver from every search. */
  private async freeIfStale(driverId: string): Promise<void> {
    const tripId = await this.location.activeTrip(driverId);
    if (!tripId) return;
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId }, select: { driverId: true, status: true } });
    const onTrip: TripStatus[] = [TripStatus.DRIVER_ASSIGNED, TripStatus.DRIVER_ARRIVED, TripStatus.IN_PROGRESS, TripStatus.PICKED_UP];
    if (trip?.driverId !== driverId || !onTrip.includes(trip.status)) await this.location.releaseBusy(driverId, tripId);
  }

  async goOffline(driverId: string): Promise<Driver> {
    const driver = await this.prisma.driver.update({ where: { id: driverId }, data: { isOnline: false } });
    await this.state.set(driverId, { isOnline: false, vehicleKind: driver.vehicleKind, isBlocked: false });
    await this.location.remove({ driverId, kind: driver.vehicleKind });
    await this.earnings.sessionEnded(driverId);
    return driver;
  }
}
