import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomInt } from 'node:crypto';

import type { AuthUser } from '../../core/auth/auth-user.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Prisma, Trip } from '../../generated/prisma/client.js';
import { Gender, TripKind, TripStatus, type VehicleKind, WomenDriverPref } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { MAX_RIDER_NOT_WOMAN, RIDER_NOT_WOMAN } from '../drivers/women-drivers.js';
import type { FareQuote } from '../fares/fare-engine.js';
import { FARE_RULES } from '../fares/fare-rules.js';
import { DemandService } from '../geo/demand.service.js';
import { GeoService } from '../geo/geo.service.js';
import { cellAt } from '../geo/h3.util.js';
import { FaresService } from '../fares/fares.service.js';
import { NotifierService, type TripWithPeople } from '../notifications/notifier.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { asVehicle, DispatchService } from './dispatch.service.js';
import type { BookTripDto } from './dto/book-trip.dto.js';
import { SettingsService } from '../settings/settings.service.js';
import type { PositionCheckDto } from './dto/position-check.dto.js';
import { checkNearStop, positionForCheck } from './trip-position.js';
import { averageRating } from './driver-rating.js';
import { TripOtpGuard } from './trip-otp-guard.js';
import { canTransition, isFinished } from './trip-transitions.js';

/** H3 resolution stored on trips for heatmaps. */
const HEAT_RES = 8;

/** "Book any": at most this many vehicles added to one search. */
const MAX_ALSO_KINDS = 3;

/** Another vehicle a searching passenger could add: free drivers of it are within the maximum search radius. */
export interface VehicleAlternative {
  readonly vehicleKind: VehicleKind;
  readonly quote: FareQuote;
  readonly driversNearby: number;
  /** Straight-line km from the pickup to the nearest of them. */
  readonly nearestKm: number;
}

/** Both sides see who they're riding with: the driver (with name / phone) and the passenger's name / phone. */
/** "+919876543210" from "9876543210" or "+919876543210" (the DTO already checked it). */
const normalisePhone = (phone: string): string => (phone.startsWith('+91') ? phone : `+91${phone}`);

const TRIP_INCLUDE = {
  driver: { include: { user: { select: { id: true, name: true, phone: true, gender: true } } } },
  passenger: { select: { id: true, name: true, phone: true, identityStatus: true } },
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
    private readonly otpGuard: TripOtpGuard,
  ) {}

  /** Quotes, stores and starts dispatching a trip. */
  async book(passengerId: string, dto: BookTripDto): Promise<Trip> {
    const isGoods = FARE_RULES[dto.vehicleKind].isGoods;
    if (isGoods !== (dto.kind === TripKind.PARCEL)) throw new BadRequestException('Vehicle does not match trip kind');
    const [from, to] = await Promise.all([this.geo.locate(dto.pickup), this.geo.locate(dto.drop)]);
    if (!from.isServiceable || !to.isServiceable) throw new BadRequestException("Rido isn't in this area yet");
    if (dto.rider && isGoods) throw new BadRequestException('Parcels are booked with sender and receiver details');
    const riderIsWoman = dto.rider
      ? dto.rider.isWoman
      : (await this.prisma.user.findUnique({ where: { id: passengerId }, select: { gender: true } }))?.gender === Gender.FEMALE;
    const womenDriver = dto.womenDriver ?? WomenDriverPref.NONE;
    if (womenDriver !== WomenDriverPref.NONE) {
      if (isGoods) throw new BadRequestException('Butterfly is for rides only');
      if (!riderIsWoman) {
        throw new BadRequestException(
          dto.rider ? 'Butterfly is for women riders' : 'Butterfly is for women riders. Set your gender in Profile to use it',
        );
      }
      if (dto.rider) await this.checkButterflyForOthers(passengerId);
    }
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
        womenDriver,
        riderName: dto.rider?.name.trim(),
        riderPhone: dto.rider ? normalisePhone(dto.rider.phone) : undefined,
        riderIsWoman,
      },
    });
    await this.demand.recordRequest(dto.pickup, passengerId);
    await this.dispatch.start(trip);
    return trip;
  }

  /** Drivers reported (by cancel reason) that the "woman" this account booked Butterfly for was not one. */
  private async checkButterflyForOthers(passengerId: string): Promise<void> {
    const reports = await this.prisma.trip.count({
      where: { passengerId, riderName: { not: null }, cancelReason: RIDER_NOT_WOMAN },
    });
    if (reports >= MAX_RIDER_NOT_WOMAN) {
      throw new ForbiddenException('Butterfly for someone else is off for your account after reports from drivers. Contact support.');
    }
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
    // One active trip per driver: claimed before the database write, released again if the write loses.
    if (!(await this.location.claimBusy(driverId, tripId))) throw new ConflictException('Finish your current trip first');
    try {
      return await this.assign(driverId, tripId);
    } catch (e) {
      await this.location.releaseBusy(driverId, tripId);
      throw e;
    }
  }

  private async assign(driverId: string, tripId: string): Promise<Trip> {
    const [booked, driver] = await Promise.all([
      this.prisma.trip.findUnique({ where: { id: tripId } }),
      this.prisma.driver.findUnique({ where: { id: driverId }, select: { vehicleKind: true } }),
    ]);
    if (!booked) throw new NotFoundException('Trip not found');
    // "Book any": a driver of an added vehicle takes the trip as that vehicle, at its fare.
    const matched = asVehicle(booked, driver?.vehicleKind);
    const switched = matched.vehicleKind !== booked.vehicleKind;
    const { count } = await this.prisma.trip.updateMany({
      where: { id: tripId, status: TripStatus.SEARCHING },
      data: {
        status: TripStatus.DRIVER_ASSIGNED,
        driverId,
        assignedAt: new Date(),
        ...(switched && { vehicleKind: matched.vehicleKind, fare: matched.fare as Prisma.InputJsonValue, fareTotal: matched.fareTotal }),
      },
    });
    if (count === 0) throw new ConflictException('Trip already taken or cancelled');
    await this.dispatch.stop(tripId);
    return this.publish(tripId, 'DRIVER');
  }

  /**
   * "Book any" (like Namma Yatra): other vehicles of the same kind (ride / goods) the passenger could add to a slow
   * search. Only vehicles with free drivers within the maximum search radius, cheapest first, with their fare.
   */
  async alternatives(passengerId: string, tripId: string): Promise<VehicleAlternative[]> {
    const trip = await this.searchingTrip(passengerId, tripId);
    const s = await this.settings.all();
    const isGoods = FARE_RULES[trip.vehicleKind].isGoods;
    const kinds = (Object.keys(FARE_RULES) as VehicleKind[]).filter(
      (k) => FARE_RULES[k].isGoods === isGoods && k !== trip.vehicleKind && !trip.alsoKinds.includes(k),
    );
    const pickup = { lat: trip.pickupLat, lng: trip.pickupLng };
    const route = { distanceKm: trip.distanceKm, durationMin: trip.durationMin };
    const radiusKm = Math.max(s.searchRadiusKm, s.maxSearchRadiusKm);
    const found = await Promise.all(
      kinds.map(async (vehicleKind): Promise<VehicleAlternative | null> => {
        const drivers = await this.location.nearby({ kind: vehicleKind, ...pickup, radiusKm, limit: 5 });
        if (drivers.length === 0) return null;
        // Same route as the booking, so the fares compare like the vehicle list did.
        const quote = await this.fares.quoteOnRoute({ pickup, route, vehicleKind });
        const nearestKm = Math.round(Math.min(...drivers.map((d) => d.distanceKm)) * 10) / 10;
        return { vehicleKind, quote, driversNearby: drivers.length, nearestKm };
      }),
    );
    return found.filter((a): a is VehicleAlternative => a !== null).sort((a, b) => a.quote.total - b.quote.total);
  }

  /** Adds [vehicleKind] to a searching trip ("Book any"): its drivers get the offer too, at that vehicle's fare. */
  async addVehicle(passengerId: string, tripId: string, vehicleKind: VehicleKind): Promise<Trip> {
    const trip = await this.searchingTrip(passengerId, tripId);
    if (FARE_RULES[vehicleKind].isGoods !== FARE_RULES[trip.vehicleKind].isGoods) {
      throw new BadRequestException("That vehicle can't take this trip");
    }
    if (vehicleKind === trip.vehicleKind || trip.alsoKinds.includes(vehicleKind)) {
      return this.prisma.trip.findUniqueOrThrow({ where: { id: tripId }, include: TRIP_INCLUDE });
    }
    if (trip.alsoKinds.length >= MAX_ALSO_KINDS) throw new BadRequestException('You already added the other vehicles');
    const quote = await this.fares.quoteOnRoute({
      pickup: { lat: trip.pickupLat, lng: trip.pickupLng },
      route: { distanceKm: trip.distanceKm, durationMin: trip.durationMin },
      vehicleKind,
    });
    const alsoFares = { ...(trip.alsoFares as Record<string, FareQuote> | null), [vehicleKind]: quote };
    const { count } = await this.prisma.trip.updateMany({
      where: { id: tripId, status: TripStatus.SEARCHING },
      data: { alsoKinds: { push: vehicleKind }, alsoFares: alsoFares as unknown as Prisma.InputJsonValue },
    });
    if (count === 0) throw new ConflictException('The search has already ended');
    await this.dispatch.widen(tripId);
    return this.publish(tripId, 'PASSENGER');
  }

  private async searchingTrip(passengerId: string, tripId: string): Promise<Trip> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.passengerId !== passengerId) throw new NotFoundException('Trip not found');
    if (trip.status !== TripStatus.SEARCHING) throw new ConflictException('The search has already ended');
    return trip;
  }

  async decline(driverId: string, tripId: string): Promise<void> {
    if ((await this.dispatch.offeredTo(tripId)) === driverId) await this.dispatch.decline(tripId, driverId);
  }

  /** Driver at the pickup. Too far from it without a reason → 422 TOO_FAR (see [checkNearStop]). */
  async arrived(driverId: string, tripId: string, pos: PositionCheckDto = {}): Promise<Trip> {
    const trip = await this.driverTrip(driverId, tripId);
    if (trip.status === TripStatus.DRIVER_ARRIVED) return this.current(tripId);
    const check = checkNearStop({
      stop: 'pickup',
      at: await this.driverPosition(driverId, pos),
      target: { lat: trip.pickupLat, lng: trip.pickupLng },
      radiusM: await this.settings.get('arrivalRadiusM'),
      farReason: pos.farReason,
    });
    return this.move({ driverId, tripId, to: TripStatus.DRIVER_ARRIVED, data: { arrivedDistanceM: check.distanceM, arrivedFarReason: check.farReason } });
  }

  /** The server's fresh GPS fix, else the one sent with the request (see [positionForCheck]). */
  private async driverPosition(driverId: string, pos: PositionCheckDto): Promise<{ lat: number; lng: number } | null> {
    return positionForCheck({ server: await this.location.lastFix(driverId), sent: pos, now: Date.now() });
  }

  /** Ride: driver enters the passenger's OTP to start (5 tries a minute, [TripOtpGuard]). Parcel: marks picked up. */
  async start(driverId: string, tripId: string, otp?: string): Promise<Trip> {
    const trip = await this.driverTrip(driverId, tripId);
    // A retry (double tap, lost response) of a start that already went through.
    if (trip.status === TripStatus.IN_PROGRESS || trip.status === TripStatus.PICKED_UP) return this.current(tripId);
    if (trip.kind === TripKind.PARCEL) return this.move({ driverId, tripId, to: TripStatus.PICKED_UP, data: { startedAt: new Date() } });
    await this.otpGuard.check({ tripId, expected: trip.otp, given: otp, who: 'rider' });
    return this.move({ driverId, tripId, to: TripStatus.IN_PROGRESS, data: { startedAt: new Date() } });
  }

  /**
   * Ride: end trip. Parcel: receiver's OTP confirms delivery. Frees the driver. Too far from the drop without a
   * reason → 422 TOO_FAR (the OTP is checked first so the driver isn't asked for a reason and then told it's wrong).
   */
  async complete(driverId: string, tripId: string, body: { otp?: string } & PositionCheckDto = {}): Promise<Trip> {
    const trip = await this.driverTrip(driverId, tripId);
    const isParcel = trip.kind === TripKind.PARCEL;
    if (trip.status === TripStatus.COMPLETED || trip.status === TripStatus.DELIVERED) {
      await this.location.releaseBusy(driverId, tripId);
      return this.current(tripId);
    }
    if (isParcel) await this.otpGuard.check({ tripId, expected: trip.otp, given: body.otp, who: 'receiver' });
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
      // Counted in the same transaction as the guarded status change, so a double tap counts the ride once.
      after: (tx) => tx.driver.update({ where: { id: driverId }, data: { ridesCount: { increment: 1 } } }),
    });
    await this.location.releaseBusy(driverId, tripId);
    return updated;
  }

  /**
   * Cancels, guarded on the status it was checked in: if the trip moved meanwhile (a driver accepted or started),
   * it is checked again, so a cancel never overwrites a ride that has started. Cancelling twice returns the trip.
   */
  async cancel(user: AuthUser, tripId: string, reason?: string): Promise<Trip> {
    let trip = await this.get(user, tripId);
    for (let attempt = 1; ; attempt++) {
      if (trip.status === TripStatus.CANCELLED) return trip;
      if (isFinished(trip.status) || !canTransition({ kind: trip.kind, from: trip.status, to: TripStatus.CANCELLED })) {
        throw new BadRequestException('This trip can no longer be cancelled');
      }
      const { count } = await this.prisma.trip.updateMany({
        where: { id: tripId, status: trip.status },
        data: { status: TripStatus.CANCELLED, cancelReason: reason },
      });
      if (count === 1) break;
      if (attempt >= 3) throw new ConflictException('This trip is changing right now. Please try again');
      trip = await this.get(user, tripId);
    }
    await this.dispatch.stop(tripId);
    // The status matched, so this is the driver the trip had; free them only if they are still on it.
    if (trip.driverId) await this.location.releaseBusy(trip.driverId, tripId);
    return this.publish(tripId, user.driverId && trip.driverId === user.driverId ? 'DRIVER' : 'PASSENGER');
  }

  /**
   * Passenger rates the driver: the trip's rating is set only while it is still empty (a second tap → 409), and
   * the driver's rating becomes ratingSum / ratingCount, in one transaction.
   */
  async rate(passengerId: string, tripId: string, rating: number): Promise<Trip> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.passengerId !== passengerId) throw new NotFoundException('Trip not found');
    if (!isFinished(trip.status) || trip.status === TripStatus.CANCELLED || !trip.driverId) throw new BadRequestException('Only finished trips can be rated');
    const driverId = trip.driverId;
    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.trip.updateMany({ where: { id: tripId, rating: null }, data: { rating } });
      if (count === 0) throw new ConflictException('Already rated');
      // The increment locks the driver row, so ratings of two trips at once both count.
      const d = await tx.driver.update({
        where: { id: driverId },
        data: { ratingSum: { increment: rating }, ratingCount: { increment: 1 } },
        select: { ratingSum: true, ratingCount: true },
      });
      await tx.driver.update({ where: { id: driverId }, data: { rating: averageRating({ sum: d.ratingSum, count: d.ratingCount }) } });
      return tx.trip.findUniqueOrThrow({ where: { id: tripId } });
    });
  }

  private async driverTrip(driverId: string, tripId: string): Promise<Trip> {
    const trip = await this.prisma.trip.findUnique({ where: { id: tripId } });
    if (!trip || trip.driverId !== driverId) throw new NotFoundException('Trip not found');
    return trip;
  }

  /**
   * Moves the driver's trip to [to]. The update is guarded on the status it was checked in (like [accept]), so it
   * can't overwrite a change made at the same moment (e.g. the passenger cancelling). A retry of a step that
   * already went through returns the trip as it is. [after] runs in the same transaction, only if the move applied.
   */
  private async move(params: {
    driverId: string;
    tripId: string;
    to: TripStatus;
    data?: Prisma.TripUpdateManyMutationInput;
    after?: (tx: Prisma.TransactionClient) => Promise<unknown>;
  }): Promise<Trip> {
    const trip = await this.driverTrip(params.driverId, params.tripId);
    if (trip.status === params.to) return this.current(trip.id);
    if (!canTransition({ kind: trip.kind, from: trip.status, to: params.to })) {
      throw new BadRequestException(`Cannot go from ${trip.status} to ${params.to}`);
    }
    const applied = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.trip.updateMany({
        where: { id: trip.id, driverId: params.driverId, status: trip.status },
        data: { ...params.data, status: params.to },
      });
      if (count === 0) return false;
      await params.after?.(tx);
      return true;
    });
    if (!applied) {
      const now = await this.driverTrip(params.driverId, params.tripId);
      if (now.status === params.to) return this.current(trip.id);
      throw new ConflictException(now.status === TripStatus.CANCELLED ? 'This trip was cancelled' : 'This trip has changed. Please refresh');
    }
    return this.publish(trip.id, 'DRIVER');
  }

  /** The trip as it is now, for the driver (no OTP, nothing emitted). */
  private async current(tripId: string): Promise<Trip> {
    const trip = await this.prisma.trip.findUniqueOrThrow({ where: { id: tripId }, include: TRIP_INCLUDE });
    return { ...trip, otp: '' };
  }

  /** Emits the fresh trip to both sides (socket + push) and returns it. [by] caused the change. */
  private async publish(tripId: string, by: 'PASSENGER' | 'DRIVER'): Promise<Trip> {
    const trip = await this.prisma.trip.findUniqueOrThrow({ where: { id: tripId }, include: TRIP_INCLUDE });
    // Also the driver's own room: a cancel must reach the driver even if their trip-room join was lost.
    this.events.toTrip(tripId, 'trip.updated', { ...trip, otp: '' }, trip.driverId);
    this.events.toUser(trip.passengerId, 'trip.updated', trip);
    this.notifier.tripChanged(trip as TripWithPeople, by);
    return trip;
  }
}
