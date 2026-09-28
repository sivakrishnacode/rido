/** Platform settings editable in the admin panel, with their defaults. */
export const SETTING_DEFAULTS = {
  /** Platform-wide demand multiplier ("Peak time"), 1.0–1.5. 1.0 = no markup; surge zones and live demand still apply. */
  currentMultiplier: 1.0,
  /** Hard cap for any multiplier (surge zones included). */
  maxMultiplier: 1.5,
  /** Driver search radius around the pickup when a booking starts searching. */
  searchRadiusKm: 5,
  /** The radius widens while nobody accepts, up to this (few drivers early on: look farther rather than fail). */
  maxSearchRadiusKm: 15,
  /** Seconds to widen from [searchRadiusKm] to [maxSearchRadiusKm] (0 = the maximum at once). */
  searchExpandSeconds: 45,
  /** Seconds each driver has to accept an offer. */
  offerSeconds: 15,
  /** Drivers offered per booking before "No drivers". */
  maxCandidates: 5,
  /** A driver cancel before pickup sends the trip back to searching this many times; the next one cancels it. */
  maxReassigns: 2,
  /** "Driver not moving": first check max(this, notMovingEtaFactor × pickup ETA) minutes after accept. */
  notMovingMinMin: 3,
  notMovingEtaFactor: 1.5,
  /** The driver must have got at least this much closer to the pickup (straight line) since accepting. */
  notMovingMinProgressM: 150,
  /** After a nudge, check again this many minutes later; the second failed check gives the ride to another driver. */
  notMovingRecheckMin: 2,
  /** Minutes the driver waits at the pickup before they may cancel as "Passenger didn't come" (no fault). */
  noShowWaitMin: 5,
  /** Waiting charge: minutes at the pickup (after "Arrived") that are free; then each started minute costs the vehicle's `waitPerMin`. */
  freeWaitMin: 3,
  /** Waiting charge cap per trip, in rupees. */
  waitMaxCharge: 30,
  /**
   * Cancellation fee. Off until the owner decides the policy (rides are cash, there is no settlement between drivers).
   * On: a passenger who cancels after the driver arrived and waited the free minutes (verdict PASSENGER) owes
   * [cancellationFee] to that driver, added to their next completed ride as "Previous cancellation fee".
   */
  cancellationFeeEnabled: false,
  cancellationFee: 10,
  /** A started trip still running after max(this, stuckDurationFactor × estimated minutes) is flagged for admins. */
  stuckTripMinMin: 120,
  stuckDurationFactor: 4,
  /** Safety net: a trip still not started this many minutes after accept is cancelled by the system. */
  pickupHardCapMin: 60,
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
  /** Driver must be within this distance of the pickup to mark "Arrived" without giving a reason. */
  arrivalRadiusM: 250,
  /** …and within this distance of the drop to end the ride / complete the delivery without a reason. */
  dropRadiusM: 400,
  /** Support phone shown in the apps. */
  supportPhone: '+91 422 000 0000',
  /** Paid driver plans. Off = the app is free: no plan screens, no plan check when going online. */
  driverPlansEnabled: false,
  /** UPI ID that receives contributions (empty = the contribute page shows no pay button). */
  contributeUpiId: '',
  /** Name shown in the UPI app for [contributeUpiId]. */
  contributePayeeName: 'Rido',
  /** Message at the top of the contribute page. */
  contributeNote: 'Rido is free for drivers and riders: 0% commission and no subscription. Contributions pay for the servers, maps and SMS that keep it running.',
  /** Monthly running cost in rupees, shown on the contribute page as a total with this breakdown (all 0 = hidden). */
  costServersInr: 0,
  costMapsInr: 0,
  costSmsInr: 0,
  costOtherInr: 0,
} as const;

export type SettingKey = keyof typeof SETTING_DEFAULTS;
export type Settings = {
  -readonly [K in SettingKey]: (typeof SETTING_DEFAULTS)[K] extends number ? number : (typeof SETTING_DEFAULTS)[K] extends boolean ? boolean : string;
};
