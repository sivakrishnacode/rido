import { createHmac, timingSafeEqual } from 'node:crypto';

/** A share link works this long after the trip ends (completed, delivered or cancelled). */
export const SHARE_AFTER_END_MS = 30 * 60_000;
/** Hard cap for a link made while the trip is still running (its end is not known yet). */
export const SHARE_MAX_MS = 12 * 3600_000;

/** Signature length in base64url characters (128 bits). */
const SIG_CHARS = 22;

/** What a valid token says. */
export interface ShareClaims {
  readonly tripId: string;
  /** Epoch ms after which the token is refused whatever the trip does. */
  readonly exp: number;
}

/** The signing key, derived from the API's JWT secret so a share token can never pass as a JWT (or the other way). */
function key(secret: string): Buffer {
  return createHmac('sha256', secret).update('rido:trip-share:v1').digest();
}

function sign(body: string, secret: string): string {
  return createHmac('sha256', key(secret)).update(body).digest('base64url').slice(0, SIG_CHARS);
}

/** `<tripId>.<exp base36>.<signature>`: URL-safe (trip ids are cuids). */
export function signShareToken(claims: ShareClaims, secret: string): string {
  const body = `${claims.tripId}.${Math.floor(claims.exp).toString(36)}`;
  return `${body}.${sign(body, secret)}`;
}

/** The claims of a well-formed, correctly signed, unexpired [token]; null otherwise. */
export function verifyShareToken(token: string, secret: string, now = Date.now()): ShareClaims | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [tripId, exp36, sig] = parts;
  if (!/^[a-z0-9]{8,40}$/i.test(tripId) || !/^[a-z0-9]{1,12}$/.test(exp36) || sig.length !== SIG_CHARS) return null;
  const expected = Buffer.from(sign(`${tripId}.${exp36}`, secret));
  const given = Buffer.from(sig);
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) return null;
  const exp = parseInt(exp36, 36);
  if (!Number.isFinite(exp) || exp <= now) return null;
  return { tripId, exp };
}

/** When a link to a trip should stop working: 30 min after it ended, else [SHARE_MAX_MS] from [now]. */
export function shareExpiry(endedAt: Date | null, now = Date.now()): number {
  return endedAt ? endedAt.getTime() + SHARE_AFTER_END_MS : now + SHARE_MAX_MS;
}

/** A link is still live: the token is valid (checked before) and the trip ended less than 30 min ago (or runs). */
export function isShareLive(endedAt: Date | null, now = Date.now()): boolean {
  return !endedAt || now < endedAt.getTime() + SHARE_AFTER_END_MS;
}
