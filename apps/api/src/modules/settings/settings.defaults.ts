/** Platform settings editable in the admin panel, with their defaults. */
export const SETTING_DEFAULTS = {
  /** Default demand multiplier ("Peak time"), 1.0–1.5. */
  currentMultiplier: 1.1,
  /** Hard cap for any multiplier (surge zones included). */
  maxMultiplier: 1.5,
  /** Driver search radius around the pickup. */
  searchRadiusKm: 5,
  /** Seconds each driver has to accept an offer. */
  offerSeconds: 15,
  /** Drivers offered per booking before "No drivers". */
  maxCandidates: 5,
  /** Free-trial length for new drivers. */
  trialDays: 30,
  /** Days a lapsed plan can still go online. */
  graceDays: 2,
  /** Collect bookings for this long, then assign drivers across the whole batch. */
  batchWindowMs: 2000,
  /** Rank candidates by road ETA (Google Routes, cached per hex pair) instead of straight-line estimate. */
  useRoadEta: true,
  /** Automatic surge from live demand vs free drivers per H3 cell (res 7). */
  dynamicSurgeEnabled: true,
  /** Extra multiplier per unit of (requests ÷ free drivers) above 1, e.g. 0.1 → ratio 3 = 1.2x. */
  surgeSensitivity: 0.1,
  /** Minutes of bookings counted as current demand. */
  demandWindowMin: 15,
  /** Minimum bookings in a cell before it can surge or be shown as high demand. */
  surgeMinRequests: 3,
  /** Use learned hex-to-hex speeds for ETAs when a pair has at least this many trips (0 = off). */
  historicalEtaMinTrips: 5,
  /** Support phone shown in the apps. */
  supportPhone: '+91 422 000 0000',
} as const;

export type SettingKey = keyof typeof SETTING_DEFAULTS;
export type Settings = {
  -readonly [K in SettingKey]: (typeof SETTING_DEFAULTS)[K] extends number ? number : (typeof SETTING_DEFAULTS)[K] extends boolean ? boolean : string;
};
