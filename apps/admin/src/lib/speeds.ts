import type { HexStatRow } from "./types";

export function hourLabel(h: number): string {
  return `${String(h).padStart(2, "0")}:00`;
}

/** Trip-weighted average speed per IST hour across the listed pairs. */
export function speedByHour(rows: readonly HexStatRow[]): { hour: string; speed: number; trips: number }[] {
  const acc = Array.from({ length: 24 }, () => ({ w: 0, n: 0 }));
  for (const r of rows) {
    acc[r.hour].w += r.avgSpeedKmh * r.trips;
    acc[r.hour].n += r.trips;
  }
  return acc.flatMap((a, h) => (a.n ? [{ hour: hourLabel(h), speed: Math.round((a.w / a.n) * 10) / 10, trips: a.n }] : []));
}

