import type { PrismaService } from '../../core/prisma/prisma.service.js';
import { Gender, WomenDriverPref } from '../../generated/prisma/enums.js';

/**
 * Butterfly, PREFERRED: a man is ranked as if he were this many minutes further away, so a woman driver up to that
 * much slower still gets the offer first. The trip still goes to men when no woman is near.
 */
export const PREFERRED_HEAD_START_MIN = 8;

/** Driver cancel reason on a Butterfly ride booked for someone else: the person at the pickup is not a woman. */
export const RIDER_NOT_WOMAN = 'Rider is not a woman';

/** After this many such cancels, the account can no longer book Butterfly rides for someone else. */
export const MAX_RIDER_NOT_WOMAN = 2;

/** The ids among [driverIds] whose account says FEMALE. */
export async function womenAmong(prisma: PrismaService, driverIds: readonly string[]): Promise<Set<string>> {
  if (driverIds.length === 0) return new Set();
  const rows = await prisma.driver.findMany({
    where: { id: { in: [...driverIds] }, user: { gender: Gender.FEMALE } },
    select: { id: true },
  });
  return new Set(rows.map((r) => r.id));
}

/**
 * Applies a Butterfly preference to ranked candidates: ONLY drops men, PREFERRED gives women a head start
 * ([PREFERRED_HEAD_START_MIN]), NONE changes nothing. [etaMin] becomes the ranking key.
 */
export function applyWomenPref<T extends { readonly driverId: string; readonly etaMin: number }>(
  candidates: readonly T[],
  pref: WomenDriverPref,
  women: ReadonlySet<string>,
): T[] {
  switch (pref) {
    case WomenDriverPref.ONLY:
      return candidates.filter((c) => women.has(c.driverId));
    case WomenDriverPref.PREFERRED:
      return candidates.map((c) => (women.has(c.driverId) ? c : { ...c, etaMin: c.etaMin + PREFERRED_HEAD_START_MIN }));
    default:
      return [...candidates];
  }
}
