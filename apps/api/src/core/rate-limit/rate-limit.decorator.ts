import { SetMetadata } from '@nestjs/common';

/** One endpoint's limit: at most [limit] calls per [windowS] seconds, per user when signed in, else per IP. */
export interface RateLimitRule {
  /** Redis key part, unique per rule. */
  readonly name: string;
  readonly limit: number;
  readonly windowS: number;
}

export const RATE_LIMIT_KEY = 'rateLimit';

/**
 * The limits (one place, so they are easy to tune; documented in using.tech.md). Paid Google calls: places, routes
 * and fare quotes (a quote may fetch a route). Sign-in: per IP, on top of the per-phone OTP limits.
 */
export const LIMITS = {
  authOtp: { name: 'auth-otp', limit: 10, windowS: 900 },
  authVerify: { name: 'auth-verify', limit: 20, windowS: 900 },
  placesAutocomplete: { name: 'places-ac', limit: 60, windowS: 60 },
  placeDetails: { name: 'places-details', limit: 30, windowS: 60 },
  placesReverse: { name: 'places-reverse', limit: 30, windowS: 60 },
  mapsRoute: { name: 'maps-route', limit: 60, windowS: 60 },
  faresQuote: { name: 'fares-quote', limit: 60, windowS: 60 },
  shiftingQuote: { name: 'fares-shifting', limit: 30, windowS: 60 },
} as const satisfies Record<string, RateLimitRule>;

/** Limits a route ([RateLimitGuard]): per signed-in user, else per client IP. Admins are not limited. */
export const RateLimit = (rule: RateLimitRule): MethodDecorator & ClassDecorator => SetMetadata(RATE_LIMIT_KEY, rule);
