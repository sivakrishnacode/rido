import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { FileStorageService, type UploadedBlob } from '../../core/storage/file-storage.service.js';
import { DriverEarningsService } from './driver-earnings.service.js';
import type { UpdateDriverDto } from './dto/update-driver.dto.js';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Driver, KycDocument } from '../../generated/prisma/client.js';
import { DriverStatus, KycDocType, KycStatus, Role } from '../../generated/prisma/enums.js';
import { AuthService } from '../auth/auth.service.js';
import { SubscriptionsService } from '../subscriptions/subscriptions.service.js';
import { DriverLocationService } from './driver-location.service.js';
import type { RegisterDriverDto } from './dto/register-driver.dto.js';
import { NotifierService } from '../notifications/notifier.service.js';

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
  ) {}

  /** Creates the driver, 5 KYC rows and a 30-day free trial; returns a token with the DRIVER role. */
  async register(userId: string, dto: RegisterDriverDto): Promise<{ driver: Driver; accessToken: string }> {
    const { name, ...vehicle } = dto;
    const driver = await this.prisma.$transaction(async (tx) => {
      await tx.user.update({ where: { id: userId }, data: { name, role: Role.DRIVER } });
      return tx.driver.create({
        data: {
          ...vehicle,
          plate: vehicle.plate.toUpperCase(),
          userId,
          documents: { create: Object.values(KycDocType).map((type) => ({ type })) },
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

  documents(driverId: string): Promise<KycDocument[]> {
    return this.prisma.kycDocument.findMany({ where: { driverId }, orderBy: { type: 'asc' } });
  }

  /** Profile edits (D-25). Name and gender live on the user; the rest on the driver. */
  async update(driverId: string, dto: UpdateDriverDto): Promise<Driver> {
    const { name, gender, ...vehicle } = dto;
    const driver = await this.prisma.driver.update({
      where: { id: driverId },
      data: { ...vehicle, plate: vehicle.plate?.toUpperCase(), ...(name || gender ? { user: { update: { name, gender } } } : {}) },
    });
    return this.me(driver.id);
  }

  /** Stores the photo / PDF and puts the document under review. `fileUrl` holds the stored file name. */
  async uploadDocument(params: { driverId: string; type: KycDocType; file?: UploadedBlob }): Promise<KycDocument> {
    const fileUrl = await this.files.save(params.file);
    return this.prisma.kycDocument.update({
      where: { driverId_type: { driverId: params.driverId, type: params.type } },
      data: { status: KycStatus.UNDER_REVIEW, fileUrl, rejectReason: null },
    });
  }

  /** Admin review: verifies all documents and approves the driver (or rejects one document). */
  async review(params: { driverId: string; isApproved: boolean; rejectType?: KycDocType; reason?: string }): Promise<Driver> {
    if (params.isApproved) {
      await this.prisma.kycDocument.updateMany({ where: { driverId: params.driverId }, data: { status: KycStatus.VERIFIED } });
      void this.notifier.kycReviewed({ driverId: params.driverId, status: 'APPROVED' });
      return this.prisma.driver.update({ where: { id: params.driverId }, data: { status: DriverStatus.APPROVED } });
    }
    if (!params.rejectType) throw new BadRequestException('rejectType is required when rejecting');
    void this.notifier.kycReviewed({ driverId: params.driverId, type: params.rejectType, status: 'REJECTED', reason: params.reason });
    await this.prisma.kycDocument.update({
      where: { driverId_type: { driverId: params.driverId, type: params.rejectType } },
      data: { status: KycStatus.REJECTED, rejectReason: params.reason ?? 'Please upload a clearer image' },
    });
    return this.prisma.driver.update({ where: { id: params.driverId }, data: { status: DriverStatus.REJECTED } });
  }

  async goOnline(params: { driverId: string; lat: number; lng: number }): Promise<Driver> {
    const driver = await this.prisma.driver.findUniqueOrThrow({ where: { id: params.driverId } });
    if (driver.status !== DriverStatus.APPROVED) throw new ForbiddenException(`Account is ${driver.status.toLowerCase()}`);
    if (!(await this.subs.canGoOnline(driver.id))) throw new ForbiddenException('Plan expired. Renew to go online again');
    await this.location.update({ driverId: driver.id, kind: driver.vehicleKind, lat: params.lat, lng: params.lng });
    await this.earnings.sessionStarted(driver.id);
    return this.prisma.driver.update({ where: { id: driver.id }, data: { isOnline: true } });
  }

  async goOffline(driverId: string): Promise<Driver> {
    const driver = await this.prisma.driver.update({ where: { id: driverId }, data: { isOnline: false } });
    await this.location.remove({ driverId, kind: driver.vehicleKind });
    await this.earnings.sessionEnded(driverId);
    return driver;
  }

  async heartbeat(params: { driverId: string; lat: number; lng: number }): Promise<void> {
    const driver = await this.prisma.driver.findUniqueOrThrow({ where: { id: params.driverId } });
    if (driver.isOnline) await this.location.update({ ...params, kind: driver.vehicleKind });
  }
}
