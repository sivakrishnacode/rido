import type { EtaSource } from "./types";

export function hourLabel(h: number): string {
  return `${String(h).padStart(2, "0")}:00`;
}

/** Rush hours in Coimbatore (IST): 8–10 am and 5–8 pm. */
export const PEAK_HOURS: readonly number[] = [8, 9, 10, 17, 18, 19, 20];

/** Peak vs off-peak speed (total km / total time) and how much slower the peak is, in %. */
export function peakVsOffPeak(byHour: readonly { hour: number; speed: number; trips: number }[]): {
  peak: number | null;
  offPeak: number | null;
  slowdownPct: number | null;
} {
  // Trips × (1 / speed) is proportional to time for equal-length trips, so a trip-weighted harmonic mean.
  const mean = (rows: typeof byHour) => {
    const trips = rows.reduce((a, r) => a + r.trips, 0);
    const inv = rows.reduce((a, r) => a + (r.speed > 0 ? r.trips / r.speed : 0), 0);
    return trips && inv ? trips / inv : null;
  };
  const peak = mean(byHour.filter((r) => PEAK_HOURS.includes(r.hour)));
  const offPeak = mean(byHour.filter((r) => !PEAK_HOURS.includes(r.hour)));
  return { peak, offPeak, slowdownPct: peak && offPeak ? (1 - peak / offPeak) * 100 : null };
}

/** How a pair's speed compares with the city average at the same hour, in % (negative = slower). */
export function vsHourAvg(speed: number, hour: number, byHour: readonly { hour: number; speed: number }[]): number | null {
  const avg = byHour.find((r) => r.hour === hour)?.speed;
  return avg ? (speed / avg - 1) * 100 : null;
}

export const ETA_SOURCE_LABEL: Record<EtaSource, string> = {
  res9: "Street hex pair",
  res8: "Neighbourhood pair",
  res7: "District pair",
  "all-day": "All-day average",
  fallback: "No data (20 km/h guess)",
};
