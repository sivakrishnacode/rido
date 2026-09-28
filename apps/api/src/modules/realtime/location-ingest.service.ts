import { Injectable } from '@nestjs/common';

import { DriverStateCache } from '../../core/driver-state/driver-state.cache.js';
import type { VehicleKind } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { SAFETY_CHECK_EVENT, SafetyMonitorService, safetyCheckPayload } from '../safety/safety-monitor.service.js';
import { type LocationFix, sanitizeBatch } from '../drivers/location-fix.js';
import { TripEventsService } from './trip-events.service.js';
import { TripTrackService } from './trip-track.service.js';

/** What happened to an upload: fixes that were valid, and whether the newest one moved the live position. */
export interface IngestResult {
  readonly accepted: number;
  readonly isLive: boolean;
}

/**
 * One path for every driver GPS upload (socket `driver:location` / `driver:locations`, HTTP heartbeat and batch):
 * validates the fixes, moves the driver in the dispatch index with the newest one, streams it to the trip room and
 * records all of them on the driver's active trip (breadcrumbs, [TripTrackService]) and runs the ride safety checks
 * ([SafetyMonitorService]).
 * A batch (fixes buffered while the socket was down) is processed oldest first; an older fix never overwrites a
 * newer live position.
 */
@Injectable()
export class LocationIngestService {
  constructor(
    private readonly drivers: DriverStateCache,
    private readonly location: DriverLocationService,
    private readonly events: TripEventsService,
    private readonly track: TripTrackService,
    private readonly safety: SafetyMonitorService,
  ) {}

  /** A live fix: stamped with the server time in the index (it just arrived). */
  live(driverId: string, raw: unknown): Promise<IngestResult> {
    return this.ingest(driverId, [raw], true);
  }

  /** Buffered fixes: the newest one counts as the position at its own time, if nothing newer arrived meanwhile. */
  batch(driverId: string, raw: unknown): Promise<IngestResult> {
    return this.ingest(driverId, raw, false);
  }

  private async ingest(driverId: string, raw: unknown, isLiveUpload: boolean): Promise<IngestResult> {
    const now = Date.now();
    const fixes = sanitizeBatch(Array.isArray(raw) ? raw : [], now);
    if (!fixes.length) return { accepted: 0, isLive: false };
    // Cached (no database read per fix); see DriverStateCache for when it is refreshed.
    const driver = await this.drivers.get(driverId);
    if (!driver?.isOnline || driver.isBlocked) return { accepted: 0, isLive: false };
    const newest = fixes[fixes.length - 1];
    const [last, tripId] = await Promise.all([this.location.lastFix(driverId), this.location.activeTrip(driverId)]);
    if (tripId) {
      await this.track.append(tripId, fixes);
      // Ride safety checks (long stop, route change at night): "Is everything OK?" to the passenger's screen too.
      for (const c of await this.safety.onFixes(tripId, fixes)) this.events.toUser(c.passengerId, SAFETY_CHECK_EVENT, safetyCheckPayload(c));
    }
    const at = isLiveUpload ? now : newest.ts;
    // An older fix (a late flush) never overwrites a newer live position.
    if (last?.at != null && last.at > at) return { accepted: fixes.length, isLive: false };
    await this.moveTo(driverId, driver.vehicleKind, newest, at, tripId);
    return { accepted: fixes.length, isLive: true };
  }

  private async moveTo(driverId: string, kind: VehicleKind, fix: LocationFix, at: number, tripId: string | null): Promise<void> {
    await this.location.update({ driverId, kind, lat: fix.lat, lng: fix.lng, at });
    if (tripId) this.events.toTrip(tripId, 'trip.location', { tripId, lat: fix.lat, lng: fix.lng, at, hdg: fix.hdg });
  }
}
