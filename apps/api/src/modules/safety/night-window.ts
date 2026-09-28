/** IST = UTC + 5:30 (no daylight saving). */
const IST_OFFSET_MIN = 330;

/** The hour (0–23) in India at [at]. */
export function istHourOf(at: Date): number {
  const min = (at.getUTCHours() * 60 + at.getUTCMinutes() + IST_OFFSET_MIN) % 1440;
  return Math.floor(min / 60);
}

/**
 * True when [at] falls in the night window, in IST: from [startHour] (inclusive) to [endHour] (exclusive), wrapping
 * past midnight when start > end (settings `nightStartHour` 22, `nightEndHour` 5 → 22:00–04:59). start === end = never.
 */
export function isNightIst(at: Date, startHour: number, endHour: number): boolean {
  const h = istHourOf(at);
  if (startHour === endHour) return false;
  return startHour < endHour ? h >= startHour && h < endHour : h >= startHour || h < endHour;
}
