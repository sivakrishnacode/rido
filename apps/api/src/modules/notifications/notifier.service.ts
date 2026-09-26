import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../core/prisma/prisma.service.js';
import type { Announcement, Trip } from '../../generated/prisma/client.js';
import { AnnouncementAudience, AppKind, TripKind, TripStatus } from '../../generated/prisma/enums.js';
import { PUSH_TOPICS, PushService } from './push.service.js';

type Party = { name: string | null; phone?: string | null };
/** A trip with its people, as `TripsService` loads it. */
export type TripWithPeople = Trip & {
  driver?: ({ userId: string; plate: string; vehicleModel: string; user: Party } & object) | null;
  passenger?: ({ id: string } & Party) | null;
};

const DOC_LABEL: Record<string, string> = {
  DRIVING_LICENCE: 'Driving licence',
  AADHAAR: 'Aadhaar',
  VEHICLE_RC: 'Vehicle RC',
  INSURANCE: 'Vehicle insurance',
  POLICE_VERIFICATION: 'Police verification',
};

function first(name: string | null | undefined, fallback: string): string {
  return (name ?? '').trim().split(/\s+/)[0] || fallback;
}

/**
 * What each event says, and to whom. Passenger app: trip progress, no drivers, chat. Driver app: ride requests
 * (urgent), cancellations, chat, KYC decisions. Both: admin announcements on topics.
 */
@Injectable()
export class NotifierService {
  constructor(
    private readonly push: PushService,
    private readonly prisma: PrismaService,
  ) {}

  /** After a status change. [by] = who caused it (a cancellation is only pushed to the other side). */
  tripChanged(trip: TripWithPeople, by: 'PASSENGER' | 'DRIVER' | 'SYSTEM'): void {
    const isParcel = trip.kind === TripKind.PARCEL;
    const driver = first(trip.driver?.user.name, 'Your driver');
    const data = { type: 'trip', tripId: trip.id, status: trip.status, kind: trip.kind };
    const toPassenger = (title: string, body: string): void =>
      this.push.toUser(trip.passengerId, AppKind.PASSENGER, { title, body, channel: 'trip_updates', data });

    switch (trip.status) {
      case TripStatus.DRIVER_ASSIGNED:
        return toPassenger(
          isParcel ? 'Delivery partner assigned' : 'Driver on the way',
          `${driver} · ${trip.driver?.plate ?? ''} is coming to ${trip.pickupName}. ${isParcel ? 'Delivery' : 'Ride'} OTP ${trip.otp}`,
        );
      case TripStatus.DRIVER_ARRIVED:
        return toPassenger(`${driver} has arrived`, isParcel ? `At ${trip.pickupName} to collect the parcel` : `At ${trip.pickupName}. Share OTP ${trip.otp} to start`);
      case TripStatus.IN_PROGRESS:
        return toPassenger('Ride started', `On the way to ${trip.dropName}`);
      case TripStatus.PICKED_UP:
        return toPassenger('Parcel picked up', `On the way to ${trip.dropName}. The receiver needs OTP ${trip.otp}`);
      case TripStatus.COMPLETED:
        return toPassenger("You've arrived", `Pay ₹${trip.fareTotal} to ${driver}. Tap to rate your ride`);
      case TripStatus.DELIVERED:
        return toPassenger('Parcel delivered', `Delivered at ${trip.dropName}`);
      case TripStatus.NO_DRIVERS:
        return toPassenger('No drivers nearby', 'Please try again in a minute or pick another vehicle');
      case TripStatus.CANCELLED:
        if (by === 'DRIVER') return toPassenger(`${isParcel ? 'Delivery' : 'Ride'} cancelled`, `${driver} cancelled. Please book again`);
        if (by === 'PASSENGER' && trip.driver) {
          this.push.toUser(trip.driver.userId, AppKind.DRIVER, {
            title: `${isParcel ? 'Delivery' : 'Ride'} cancelled`,
            body: `${first(trip.passenger?.name, 'The customer')} cancelled${trip.cancelReason ? `: ${trip.cancelReason}` : ''}`,
            channel: 'trip_updates',
            data,
          });
        }
        return;
      default:
        return;
    }
  }

  /** New request for a driver: urgent (wakes the phone), dropped by FCM once the offer has expired. */
  async offer(params: { driverId: string; trip: Trip; pickupEtaMin: number | null; expiresInSeconds: number }): Promise<void> {
    const driver = await this.prisma.driver.findUnique({ where: { id: params.driverId }, select: { userId: true } });
    if (!driver) return;
    const t = params.trip;
    const eta = params.pickupEtaMin ? ` · ${params.pickupEtaMin} min away` : '';
    this.push.toUser(driver.userId, AppKind.DRIVER, {
      title: `New ${t.kind === TripKind.PARCEL ? 'delivery' : 'ride'} request · ₹${t.fareTotal}`,
      body: `${t.pickupName} → ${t.dropName}${eta}`,
      channel: 'ride_requests',
      data: { type: 'offer', tripId: t.id },
      isUrgent: true,
      ttlSeconds: params.expiresInSeconds,
    });
  }

  /** Chat message to the other side of the trip. */
  async chat(params: { tripId: string; from: 'PASSENGER' | 'DRIVER'; text: string }): Promise<void> {
    const trip = await this.prisma.trip.findUnique({
      where: { id: params.tripId },
      include: { driver: { select: { userId: true, user: { select: { name: true } } } }, passenger: { select: { name: true } } },
    });
    if (!trip) return;
    const data = { type: 'chat', tripId: trip.id };
    const body = params.text.length > 140 ? `${params.text.slice(0, 137)}…` : params.text;
    if (params.from === 'PASSENGER' && trip.driver) {
      this.push.toUser(trip.driver.userId, AppKind.DRIVER, { title: first(trip.passenger.name, 'Customer'), body, channel: 'chat', data });
    } else if (params.from === 'DRIVER') {
      this.push.toUser(trip.passengerId, AppKind.PASSENGER, { title: first(trip.driver?.user.name, 'Your driver'), body, channel: 'chat', data });
    }
  }

  /** An admin verified or rejected a KYC document (or the whole application). */
  async kycReviewed(params: { driverId: string; type?: string; status: 'VERIFIED' | 'REJECTED' | 'APPROVED'; reason?: string | null }): Promise<void> {
    const driver = await this.prisma.driver.findUnique({ where: { id: params.driverId }, select: { userId: true } });
    if (!driver) return;
    const data = { type: 'kyc', status: params.status };
    if (params.status === 'APPROVED') {
      this.push.toUser(driver.userId, AppKind.DRIVER, { title: "You're approved! 🎉", body: 'Choose a plan and go online to start earning', channel: 'account', data });
    } else if (params.status === 'REJECTED') {
      const doc = DOC_LABEL[params.type ?? ''] ?? 'A document';
      this.push.toUser(driver.userId, AppKind.DRIVER, {
        title: `${doc} needs attention`,
        body: `${params.reason ?? 'Please upload a clearer photo'}. Tap to re-upload`,
        channel: 'account',
        data,
      });
    }
  }

  /** Admin announcement → the matching topic. */
  announcement(a: Announcement): void {
    if (!a.isActive || a.startsAt > new Date()) return;
    const topic = a.audience === AnnouncementAudience.PASSENGER ? PUSH_TOPICS.PASSENGER : a.audience === AnnouncementAudience.DRIVER ? PUSH_TOPICS.DRIVER : PUSH_TOPICS.ALL;
    this.push.toTopic(topic, { title: a.title, body: a.body, channel: 'announcements', data: { type: 'announcement', id: a.id } });
  }
}
