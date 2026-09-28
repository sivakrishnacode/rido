import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { VehicleKind } from '../../generated/prisma/enums.js';
import { DriverLocationService } from '../drivers/driver-location.service.js';
import { type LocationFix, sanitizeBatch } from '../drivers/location-fix.js';
import { TripEventsService } from './trip-events.service.js';

/** What happened to an upload: fixes that were valid, and whether the newest one moved the live position. */
export interface IngestResult {
  readonly accepted: number;
  readonly isLive: boolean;
}

/**
 * One path for every driver GPS upload (socket `driver:location` / `driver:locations`, HTTP heartbeat and batch):
 * validates the fixes, moves the driver in the dispatch index with the newest one and streams it to the trip room.
 * A batch (fixes buffered while the socket was down) is processed oldest first; an older fix never overwrites a
 * newer live position.
 */
@Injectable()
export class LocationIngestService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly location: DriverLocationService,
    private readonly events: TripEventsService,
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
    const driver = await this.prisma.driver.findUnique({ where: { id: driverId }, select: { isOnline: true, vehicleKind: true } });
    if (!driver?.isOnline) return { accepted: 0, isLive: false };
    const newest = fixes[fixes.length - 1];
    const isLive = await this.moveTo(driverId, driver.vehicleKind, newest, isLiveUpload ? now : newest.ts);
    return { accepted: fixes.length, isLive };
  }

  private async moveTo(driverId: string, kind: VehicleKind, fix: LocationFix, at: number): Promise<boolean> {
    const last = await this.location.lastFix(driverId);
    if (last?.at != null && last.at > at) return false;
    await this.location.update({ driverId, kind, lat: fix.lat, lng: fix.lng, at });
    const tripId = await this.location.activeTrip(driverId);
    if (tripId) this.events.toTrip(tripId, 'trip.location', { tripId, lat: fix.lat, lng: fix.lng, at, hdg: fix.hdg });
    return true;
  }
}
