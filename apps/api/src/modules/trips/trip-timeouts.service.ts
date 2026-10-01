import { Injectable, Logger, OnModuleInit } from '@nestjs/common';

import type { Job } from '../../core/jobs/job-runner.js';
import { JobsService } from '../../core/jobs/jobs.service.js';
import { PrismaService } from '../../core/prisma/prisma.service.js';
import { CancelCode, CancelledBy, TripStatus } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { haversineMeters } from '../fares/fare-engine.js';
import { NotifierService } from '../notifications/notifier.service.js';
import { TripEventsService } from '../realtime/trip-events.service.js';
import { SettingsService } from '../settings/settings.service.js';
import { pickupProgressVerdict, pickupRecheckAt, TRIP_JOBS } from './trip-timeouts.js';
import { TripsService } from './trips.service.js';

type DriverJob = Job<{ driverId: string; strikes?: number }>;

/** Socket event to the driver's app for a nudge; [kind] says which. */
export const NUDGE_EVENT = 'trip.nudge';

/**
 * The trip timeouts (like Namma Yatri's allocator jobs), run by [JobsService] and scheduled by [TripsService]:
 * - `trip.pickup-progress`: the driver hasn't got `notMovingMinProgressM` closer to the pickup since accepting →
 *   nudge ("Are you on the way?") and check again; the second failed check gives the ride to another driver
 *   (SYSTEM / DRIVER_NOT_MOVING, counts against the driver).
 * - `trip.no-show`: the no-show wait is over → the driver may cancel as "Passenger didn't come"; the passenger is
 *   told the driver is waiting.
 * - `trip.stuck`: a started trip still running long past its estimate → flagged for admins (`needsReview`) and the
 *   driver is asked to end it. Never completed automatically.
 * - `trip.pickup-cap`: still not started `pickupHardCapMin` after accept → cancelled by the system (STUCK).
 * - `trip.scheduled-dispatch`: a trip booked for later starts looking for a driver (`scheduledDispatchLeadMin` before).
 * Each handler first checks the trip is still in that step with that driver (a stale job does nothing).
 */
@Injectable()
export class TripTimeoutsService implements OnModuleInit {
  private readonly logger = new Logger(TripTimeoutsService.name);

  constructor(
    private readonly jobs: JobsService,
    private readonly prisma: PrismaService,
    private readonly trips: TripsService,
    private readonly location: DriverLocationService,
    private readonly notifier: NotifierService,
    private readonly events: TripEventsService,
    private readonly settings: SettingsService,
  ) {}

  onModuleInit(): void {
    this.jobs.register(TRIP_JOBS.pickupProgress, (j: DriverJob) => this.pickupProgress(j));
    this.jobs.register(TRIP_JOBS.noShow, (j: DriverJob) => this.noShow(j));
    this.jobs.register(TRIP_JOBS.stuck, (j: DriverJob) => this.stuck(j));
    this.jobs.register(TRIP_JOBS.pickupCap, (j: DriverJob) => this.pickupCap(j));
    this.jobs.register(TRIP_JOBS.scheduledDispatch, (j: Job<unknown>) => this.trips.startScheduled(j.id));
  }

  /** The trip, if it is still in one of [statuses] with [driverId]. */
  private async tripFor(id: string, driverId: string, statuses: readonly TripStatus[]) {
    const trip = await this.prisma.trip.findUnique({ where: { id } });
    return trip && trip.driverId === driverId && statuses.includes(trip.status) ? trip : null;
  }

  private nudgeDriver(p: { tripId: string; driverId: string; kind: string; title: string; body: string }): void {
    this.events.toDriver(p.driverId, NUDGE_EVENT, { tripId: p.tripId, kind: p.kind, title: p.title, message: p.body });
    void this.notifier.tripNudge({ to: 'DRIVER', ...p });
  }

  async pickupProgress(job: DriverJob): Promise<void> {
    const { driverId, strikes = 0 } = job.payload;
    const trip = await this.tripFor(job.id, driverId, [TripStatus.DRIVER_ASSIGNED]);
    if (!trip) return;
    const s = await this.settings.all();
    const at = await this.location.position(driverId);
    const nowM = at ? Math.round(haversineMeters(at, { lat: trip.pickupLat, lng: trip.pickupLng })) : null;
    if (trip.acceptDistanceM === null && nowM !== null) {
      // No GPS at accept: this fix becomes the baseline, judged at the next check.
      await this.prisma.trip.updateMany({ where: { id: trip.id, driverId }, data: { acceptDistanceM: nowM } });
      await this.jobs.schedule(TRIP_JOBS.pickupProgress, trip.id, pickupRecheckAt(Date.now(), s), { driverId, strikes });
      return;
    }
    const verdict = pickupProgressVerdict({ atAcceptM: trip.acceptDistanceM, nowM, minProgressM: s.notMovingMinProgressM, strikes });
    if (verdict === 'moving') return;
    if (verdict === 'strike') {
      this.nudgeDriver({
        tripId: trip.id,
        driverId,
        kind: 'NOT_MOVING',
        title: 'Are you on the way?',
        body: `Please head to ${trip.pickupName}. If you don't get closer soon, the ride goes to another driver`,
      });
      await this.jobs.schedule(TRIP_JOBS.pickupProgress, trip.id, pickupRecheckAt(Date.now(), s), { driverId, strikes: strikes + 1 });
      return;
    }
    const was = trip.acceptDistanceM === null ? 'unknown' : `${trip.acceptDistanceM} m`;
    const dropped = await this.trips.dropTrip(trip, {
      by: CancelledBy.SYSTEM,
      code: CancelCode.DRIVER_NOT_MOVING,
      note: `Not moving to the pickup: ${nowM === null ? 'no GPS' : `${nowM} m`} away, ${was} at accept`,
    });
    if (!dropped) return;
    this.logger.log(`Trip ${trip.id} taken off driver ${driverId} (not moving)`);
    this.nudgeDriver({
      tripId: trip.id,
      driverId,
      kind: 'REASSIGNED',
      title: 'Ride given to another driver',
      body: "You weren't moving towards the pickup, so we gave the ride to another driver",
    });
  }

  async noShow(job: DriverJob): Promise<void> {
    const { driverId } = job.payload;
    const trip = await this.tripFor(job.id, driverId, [TripStatus.DRIVER_ARRIVED]);
    if (!trip) return;
    const s = await this.settings.all();
    this.nudgeDriver({
      tripId: trip.id,
      driverId,
      kind: 'NO_SHOW_ALLOWED',
      title: `Waited ${s.noShowWaitMin} min`,
      body: "If the passenger still isn't here, you can cancel as \"Passenger didn't come\". It won't count against you",
    });
    void this.notifier.tripNudge({
      to: 'PASSENGER',
      tripId: trip.id,
      passengerId: trip.passengerId,
      kind: 'DRIVER_WAITING',
      title: 'Your driver is waiting',
      body: `Your driver has been at ${trip.pickupName} for ${s.noShowWaitMin} min. Please come to the pickup`,
    });
  }

  async stuck(job: DriverJob): Promise<void> {
    const { driverId } = job.payload;
    const trip = await this.tripFor(job.id, driverId, [TripStatus.IN_PROGRESS, TripStatus.PICKED_UP]);
    if (!trip || trip.needsReview) return;
    const mins = trip.startedAt ? Math.round((Date.now() - trip.startedAt.getTime()) / 60_000) : null;
    await this.prisma.trip.update({
      where: { id: trip.id },
      data: { needsReview: true, reviewNote: `Still running ${mins ?? '?'} min after start (estimate ${trip.durationMin} min)` },
    });
    this.nudgeDriver({
      tripId: trip.id,
      driverId,
      kind: 'END_TRIP',
      title: 'Did you reach the drop?',
      body: `This trip has been running for ${mins ?? 'a long'} min. Please end it in the app`,
    });
  }

  async pickupCap(job: DriverJob): Promise<void> {
    const { driverId } = job.payload;
    const trip = await this.tripFor(job.id, driverId, [TripStatus.DRIVER_ASSIGNED, TripStatus.DRIVER_ARRIVED]);
    if (!trip) return;
    const s = await this.settings.all();
    const cancelled = await this.trips.systemCancel(trip, CancelCode.STUCK, `Not started within ${s.pickupHardCapMin} min of accept`);
    if (!cancelled) return;
    this.nudgeDriver({
      tripId: trip.id,
      driverId,
      kind: 'CANCELLED',
      title: 'Ride cancelled',
      body: `The ride didn't start within ${s.pickupHardCapMin} min, so it was cancelled`,
    });
  }
}
