import { BadRequestException } from '@nestjs/common';

import { RideMode } from '../../generated/prisma/enums.js';
import { MAX_DAYS_AHEAD } from '../fares/ride-modes.js';

const DAY_MS = 86_400_000;
/** A pickup time this close counts as "now" (the trip searches at once). */
const NOW_SLACK_MS = 60_000;

/**
 * The booking's pickup time ([scheduledAt]: null = now) and an outstation round trip's return, checked: booking for
 * later is for rentals and outstation trips, up to [MAX_DAYS_AHEAD] days ahead; a round trip comes back after it
 * leaves and within [MAX_DAYS_AHEAD] days. Throws 400 with what to fix.
 */
export function bookingTimes(
  dto: { scheduledAt?: string; returnAt?: string; roundTrip?: boolean },
  mode: RideMode,
  now: Date,
): { scheduledAt: Date | null; returnAt: Date | null } {
  let scheduledAt: Date | null = null;
  if (dto.scheduledAt) {
    if (mode === RideMode.LOCAL) throw new BadRequestException('Booking for later is for rentals and outstation trips');
    const at = new Date(dto.scheduledAt);
    if (at.getTime() < now.getTime() - NOW_SLACK_MS) throw new BadRequestException('Choose a pickup time in the future');
    if (at.getTime() > now.getTime() + MAX_DAYS_AHEAD * DAY_MS) throw new BadRequestException(`You can book up to ${MAX_DAYS_AHEAD} days ahead`);
    scheduledAt = at.getTime() <= now.getTime() + NOW_SLACK_MS ? null : at;
  }
  let returnAt: Date | null = null;
  if (mode === RideMode.OUTSTATION && dto.roundTrip) {
    if (!dto.returnAt) throw new BadRequestException('Choose when you come back');
    returnAt = new Date(dto.returnAt);
    const leave = scheduledAt ?? now;
    if (returnAt.getTime() <= leave.getTime()) throw new BadRequestException('Come back after you leave');
    if (returnAt.getTime() > leave.getTime() + MAX_DAYS_AHEAD * DAY_MS) throw new BadRequestException(`A round trip can be up to ${MAX_DAYS_AHEAD} days`);
  }
  return { scheduledAt, returnAt };
}
