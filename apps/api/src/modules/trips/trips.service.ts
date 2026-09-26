import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomInt } from 'node:crypto';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Prisma, Trip } from '../../generated/prisma/client.js';
import { TripKind, TripStatus } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { FARE_RULES } from '../fares/fare-rules.js';
import { DemandService } from '../geo/demand.service.js';
import { GeoService } from '../geo/geo.service.js';
import { cellAt } from '../geo/h3.util.js';
import { FaresService } from '../fares/fares.service.js';
import { NotifierService, type TripWithPeople } from '../notifications/notifier.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { DispatchService } from './dispatch.service.js';
import type { BookTripDto } from './dto/book-trip.dto.js';
import { SettingsService } from '../settings/settings.service.js';
import type { PositionCheckDto } from './dto/position-check.dto.js';
import { checkNearStop } from './trip-position.js';
import { canTransition, isFinished } from './trip-transitions.js';

/** H3 resolution stored on trips for heatmaps. */
const HEAT_RES = 8;

/** Both sides see who they're riding with: the driver (with name / phone) and the passenger's name / phone. */
const TRIP_INCLUDE = {
  driver: { include: { user: { select: { id: true, name: true, phone: true, gender: true } } } },
  passenger: { select: { id: true, name: true, phone: true } },
} as const;

/** Rides and parcels: booking, the status lifecycle, cancel and rating. */
@Injectable()
export class TripsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fares: FaresService,
    private readonly dispatch: DispatchService,
    private readonly location: DriverLocationService,
    private readonly events: TripEventsService,
    private readonly geo: GeoService,
    private readonly demand: DemandService,
    private readonly notifier: NotifierService,
    private readonly settings: SettingsService,
  ) {}

  /** Quotes, stores and starts dispatching a trip. */
  async book(passengerId: string, dto: BookTripDto): Promise<Trip> {
    const isGoods = FARE_RULES[dto.vehicleKind].isGoods;
    if (isGoods !== (dto.kind === TripKind.PARCEL)) throw new BadRequestException('Vehicle does not match trip kind');
    const [from, to] = await Promise.all([this.geo.locate(dto.pickup), this.geo.locate(dto.drop)]);
    if (!from.isServiceable || !to.isServiceable) throw new BadRequestException("Rido isn't in this area yet");
    const quote = await this.fares.quoteOne({ pickup: dto.pickup, drop: dto.drop, vehicleKind: dto.vehicleKind });
    const trip = await this.prisma.trip.create({
      data: {
        kind: dto.kind,
        vehicleKind: dto.vehicleKind,
        passengerId,
        pickupName: dto.pickup.name ?? 'Pinned location',
        pickupAddr: dto.pickup.address ?? '',
        pickupLat: dto.pickup.lat,
        pickupLng: dto.pickup.lng,
        dropName: dto.drop.name ?? 'Pinned location',
        dropAddr: dto.drop.address ?? '',
        dropLat: dto.drop.lat,
        dropLng: dto.drop.lng,
        pickupCell: cellAt(dto.pickup.lat, dto.pickup.lng, HEAT_RES),
        dropCell: cellAt(dto.drop.lat, dto.drop.lng, HEAT_RES),
        distanceKm: quote.distanceKm,
        durationMin: quote.durationMin,
        fare: quote as unknown as Prisma.InputJsonValue,
        fareTotal: quote.total,
        otp: String(randomInt(1000, 10000)),
        paymentMode: dto.paymentMode,
        parcel: dto.parcel as Prisma.InputJsonValue | undefined,
        payer: dto.payer,
      },
    });
    await this.demand.recordRequest(dto.pickup, passengerId);
    await this.dispatch.start(trip);
    return trip;
  }

  async history(user: AuthUser): Promise<Trip[]> {
    const where = user.driverId ? { driverId: user.driverId } : { passengerId: user.userId };
    const trips = await this.prisma.trip.findMany({ where, orderBy: { createdAt: 'desc' }, take: 50, include: TRIP_INCLUDE });
    return user.driverId ? trips.map((t) => ({ ...t, otp: '' })) : trips;
  }

  /** The caller's unfinished trip (searching or on the way), to restore the app after a restart. */
  async active(user: AuthUser): Promise<Trip | null> {
    const unfinished = { notIn: [TripStatus.COMPLETED, TripStatus.DELIVERED, TripStatus.CANCELLED, TripStatus.NO_DRIVERS] };
    const where = user.driverId ? { driverId: user.driverId, status: unfinished } : { passengerId: user.userId, status: unfinished };
    const trip = await this.prisma.trip.findFirst({ where, orderBy: { createdAt: 'desc' }, include: TRIP_INCLUDE });
    if (!trip) return null;
    return user.driverId && trip.driverId === user.driverId ? { ...trip, otp: '' } : trip;
  }

  /** A trip the caller takes part in. The OTP is hidden from drivers. */
  async get(user: AuthUser, id: string): Promise<Trip> {
    const trip = await this.prisma.trip.findUnique({ where: { id }, include: TRIP_INCLUDE });
    if (!trip) throw new NotFoundException('Trip not found');
    const isPassenger = trip.passengerId === user.userId;
    if (!isPassenger && trip.driverId !== user.driverId) throw new ForbiddenException();
    return isPassenger ? trip : { ...trip, otp: '' };
  }

  async accept(driverId: string, tripId: string): Promise<Trip> {
    if ((await this.dispatch.offeredTo(tripId)) !== driverId) throw new ConflictException('This request is no longer available');
    const { count } = await this.prisma.trip.updateMany({
      where: { id: tripId, status: TripStatus.SEARCHING },
      data: { status: TripStatus.DRIVER_ASSIGNED, driverId, assignedAt: new Date() },
    });
    if (count === 0) throw new ConflictException('Trip already taken or cancelled');
    await this.dispatch.stop(tripId);
    await this.location.setBusy(driverId, tripId);
    return this.publish(tripId, 'DRIVER');
  }

  async decline(driverId: string, tripId: string): Promise<void> {
    if ((await this.dispatch.offeredTo(tripId)) === driverId) await this.dispatch.decline(tripId, driverId);
  }

  /** Driver at the pickup. Too far from it without a reason → 422 TOO_FAR (see [checkNearStop]). */
  async arrived(driverId: string, tripId: string, pos: PositionCheckDto = {}): Promise<Trip> {
    const trip = await this.driverTrip(driverId, tripId);
    const check = checkNearStop({
      stop: 'pickup',
      at: await this.driverPosition(driverId, pos),
      target: { lat: trip.pickupLat, lng: trip.pickupLng },
      radiusM: await this.settings.get('arrivalRadiusM'),
      farReason: pos.farReason,
    });
    return this.move({ driverId, tripId, to: TripStatus.DRIVER_ARRIVED, data: { arrivedDistanceM: check.distanceM, arrivedFarReason: check.farReason } });
  }

  /** The fix sent with the request, else the last one from the app's GPS stream. */
  private async driverPosition(driverId: string, pos: PositionCheckDto): Promise<{ lat: number; lng: number } | null> {
    if (pos.lat !== undefined && pos.lng !== undefined) return { lat: pos.lat, lng: pos.lng };
    return this.location.position(driverId);
  }

  /** Ride: driver enters the passenger's OTP to start. Parcel: marks picked up. */
  async start(driverId: string, tripId: string, otp?: string): Promise<Trip> {
    const trip = await this.driverTrip(driverId, tripId);
    if (trip.kind === TripKind.PARCEL) return this.move({ driverId, tripId, to: TripStatus.PICKED_UP, data: { startedAt: new Date() } });
    if (otp !== trip.otp) throw new BadRequestException('Wrong OTP, please try again');
    return this.move({ driverId, tripId, to: TripStatus.IN_PROGRESS, data: { startedAt: new Date() } });
  }

  /**
   * Ride: end trip. Parcel: receiver's OTP confirms delivery. Frees the driver. Too far from the drop without a
   * reason → 422 TOO_FAR (the OTP is checked first so the driver isn't asked for a reason and then told it's wrong).
   */
  async complete(driverId: string, tripId: string, body: { otp?: string } & PositionCheckDto = {}): Promise<Trip> {
    const trip = await this.driverTrip(driverId, tripId);
    const isParcel = trip.kind === TripKind.PARCEL;
    if (isParcel && body.otp !== trip.otp) throw new BadRequestException('Wrong OTP, please try again');
    const check = checkNearStop({
      stop: 'drop',
      at: await this.driverPosition(driverId, body),
      target: { lat: trip.dropLat, lng: trip.dropLng },
      radiusM: await this.settings.get('dropRadiusM'),
      farReason: body.farReason,
    });
    const updated = await this.move({
      driverId,
      tripId,
      to: isParcel ? TripStatus.DELIVERED : TripStatus.COMPLETED,
      data: { endedAt: new Date(), endDistanceM: check.distanceM, endFarReason: check.farReason },
    });
    await this.prisma.driver.update({ where: { id: driverId }, data: { ridesCount: { increment: 1 } } });
    await this.location.setBusy(driverId, null);
    return updated;
  }

  async cancel(user: AuthUser, tripId: string, reason?: string): Promise<Trip> {
    const trip = await this.get(user, tripId);
    if (isFinished(trip.status) || !canTransition({ kind: trip.kind, from: trip.status, to: TripStatus.CANCELLED })) {
      throw new BadRequestException('This trip can no longer be cancelled');
    }
    await this.prisma.trip.update({ where: { id: tripId }, data: { status: TripStatus.CANCELLED, cancelReason: reason } });
    await this.dispatch.stop(tripId);
    if (trip.driverId) await this.location.setBusy(trip.driverId, null);
    return this.publish(tripId, user.driverId && trip.driverId === user.driverId ? 'DRIVER' : 'PASSENGER');
  }

  /** Passenger rates the driver; updates the driver's running average. */
  async rate(passengerId: string, tripId: string, rating: number): Promise<Trip> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId }, include: { driver: true } });
    if (!trip || trip.passengerId !== passengerId) throw new NotFoundException('Trip not found');
    if (!isFinished(trip.status) || trip.status === TripStatus.CANCELLED || !trip.driver) throw new BadRequestException('Only finished trips can be rated');
    if (trip.rating) throw new ConflictException('Already rated');
    const d = trip.driver;
    const newRating = Math.round(((d.rating * d.ridesCount + rating) / (d.ridesCount + 1)) * 100) / 100;
    await this.prisma.driver.update({ where: { id: d.id }, data: { rating: newRating } });
    return this.prisma.trip.update({ where: { id: tripId }, data: { rating } });
  }

  private async driverTrip(driverId: string, tripId: string): Promise<Trip> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.driverId !== driverId) throw new NotFoundException('Trip not found');
    return trip;
  }

  private async move(params: { driverId: string; tripId: string; to: TripStatus; data?: Prisma.TripUpdateInput }): Promise<Trip> {
    const trip = await this.driverTrip(params.driverId, params.tripId);
    if (!canTransition({ kind: trip.kind, from: trip.status, to: params.to })) {
      throw new BadRequestException(`Cannot go from ${trip.status} to ${params.to}`);
    }
    await this.prisma.trip.update({ where: { id: trip.id }, data: { ...params.data, status: params.to } });
    return this.publish(trip.id, 'DRIVER');
  }

  /** Emits the fresh trip to both sides (socket + push) and returns it. [by] caused the change. */
  private async publish(tripId: string, by: 'PASSENGER' | 'DRIVER'): Promise<Trip> {
    const trip = await this.prisma.trip.findUniqueOrThrow({ where: { id: tripId }, include: TRIP_INCLUDE });
    this.events.toTrip(tripId, 'trip.updated', { ...trip, otp: '' });
    this.events.toUser(trip.passengerId, 'trip.updated', trip);
    this.notifier.tripChanged(trip as TripWithPeople, by);
    return trip;
  }
}
