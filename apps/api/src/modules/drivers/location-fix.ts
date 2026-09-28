/**
 * Driver GPS fixes as the apps send them (`driver:location`, `driver:locations`, `POST /drivers/me/location(s)`).
 * Old apps send only `{lat, lng}`; newer ones add the phone's timestamp, accuracy, speed, heading and the
 * "mock location" flag. [sanitizeFix] turns any of them into a [LocationFix] (or drops it).
 */
export interface LocationFix {
  readonly lat: number;
  readonly lng: number;
  /** When the phone took the fix (epoch ms), clamped to the server clock; the server time for old apps. */
  readonly ts: number;
  /** Horizontal accuracy in metres (68% radius), when the app sent it. */
  readonly acc: number | null;
  /** Speed in m/s, when known. */
  readonly spd: number | null;
  /** Direction of travel in degrees (0–360), when known. */
  readonly hdg: number | null;
  /** The phone reported a mock (fake-GPS app) location. */
  readonly mock: boolean;
}

/** Most fixes one batch may carry (the app buffers at most 500 while the socket is down). */
export const MAX_BATCH_FIXES = 500;
/** Fixes older than this are dropped: a flush after a very long outage adds nothing useful. */
export const MAX_FIX_AGE_MS = 12 * 3600_000;

const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);

/** A valid fix from an app payload, or null (bad or missing coordinates, (0, 0), far too old). */
export function sanitizeFix(raw: unknown, now: number): LocationFix | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  const lat = num(r.lat);
  const lng = num(r.lng);
  if (lat === null || lng === null || Math.abs(lat) > 90 || Math.abs(lng) > 180 || (lat === 0 && lng === 0)) return null;
  const sent = num(r.ts);
  // A phone clock running ahead counts as "now": the server clock is the upper bound.
  const ts = sent === null ? now : Math.min(Math.round(sent), now);
  if (now - ts > MAX_FIX_AGE_MS) return null;
  const acc = num(r.acc);
  const spd = num(r.spd);
  const hdg = num(r.hdg);
  return {
    lat,
    lng,
    ts,
    acc: acc !== null && acc >= 0 ? Math.min(acc, 100_000) : null,
    spd: spd !== null && spd >= 0 && spd <= 100 ? spd : null,
    hdg: hdg !== null && hdg >= 0 && hdg <= 360 ? hdg : null,
    mock: r.mock === true,
  };
}

/** The valid fixes of a batch (at most [MAX_BATCH_FIXES], the newest kept), oldest first. */
export function sanitizeBatch(raw: unknown, now: number): LocationFix[] {
  const list = Array.isArray(raw) ? raw : [];
  const fixes = list.map((f) => sanitizeFix(f, now)).filter((f): f is LocationFix => f !== null);
  fixes.sort((a, b) => a.ts - b.ts);
  return fixes.length > MAX_BATCH_FIXES ? fixes.slice(-MAX_BATCH_FIXES) : fixes;
}
