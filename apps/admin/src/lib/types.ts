import type { SafetyEvent, SosRecord } from "./safety";

// Response shapes of the Tamil Taxi admin API (apps/api/src/modules/admin, apps/api/prisma/schema.prisma).
// Dates arrive as ISO strings; money is whole rupees.

import type { CancelCode, CancelFault, CancelledBy } from "./cancel";

export type Role = "PASSENGER" | "DRIVER" | "ADMIN";
export type Gender = "FEMALE" | "MALE" | "PREFER_NOT_TO_SAY";
export type WorkType = "RIDES" | "DELIVERIES";
export type VehicleKind = "BIKE" | "AUTO" | "CAB" | "GOODS_BIKE" | "THREE_WHEELER" | "MINI_TRUCK" | "PICKUP" | "TRUCK";
export type DriverStatus = "PENDING" | "APPROVED" | "REJECTED" | "ON_HOLD";
export type KycDocType = "DRIVING_LICENCE" | "AADHAAR" | "VEHICLE_RC" | "INSURANCE" | "POLICE_VERIFICATION";
export type KycStatus = "NOT_UPLOADED" | "UNDER_REVIEW" | "VERIFIED" | "REJECTED";
/** Didit identity check (drivers: licence + Aadhaar + selfie; riders: optional, any ID). */
export type IdentityStatus = "NOT_STARTED" | "IN_PROGRESS" | "IN_REVIEW" | "APPROVED" | "DECLINED";
export type TripKind = "RIDE" | "PARCEL";
export type TripStatus =
  | "SEARCHING"
  | "NO_DRIVERS"
  | "DRIVER_ASSIGNED"
  | "DRIVER_ARRIVED"
  | "IN_PROGRESS"
  | "PICKED_UP"
  | "COMPLETED"
  | "DELIVERED"
  | "CANCELLED";
export type PaymentMode = "CASH" | "UPI";
export type ParcelPayer = "SENDER" | "RECEIVER";
export type PlanPeriod = "DAILY" | "WEEKLY" | "MONTHLY";
export type SubscriptionStatus = "TRIAL" | "ACTIVE" | "GRACE" | "EXPIRED" | "PAUSED" | "CANCELLED";
export type PaymentStatus = "PENDING" | "PAID" | "FAILED" | "REFUNDED";
export type TicketStatus = "OPEN" | "IN_PROGRESS" | "RESOLVED";
export type ZoneKind = "SURGE" | "DEMAND" | "NO_SERVICE" | "PICKUP_POINT";
export type AnnouncementAudience = "ALL" | "PASSENGER" | "DRIVER";

export const DRIVER_STATUSES: readonly DriverStatus[] = ["PENDING", "APPROVED", "REJECTED", "ON_HOLD"];
export const TICKET_STATUSES: readonly TicketStatus[] = ["OPEN", "IN_PROGRESS", "RESOLVED"];
export const TRIP_KINDS: readonly TripKind[] = ["RIDE", "PARCEL"];
export const TRIP_STATUSES: readonly TripStatus[] = [
  "SEARCHING",
  "NO_DRIVERS",
  "DRIVER_ASSIGNED",
  "DRIVER_ARRIVED",
  "IN_PROGRESS",
  "PICKED_UP",
  "COMPLETED",
  "DELIVERED",
  "CANCELLED",
];
export const VEHICLE_KINDS: readonly VehicleKind[] = [
  "BIKE",
  "AUTO",
  "CAB",
  "GOODS_BIKE",
  "THREE_WHEELER",
  "MINI_TRUCK",
  "PICKUP",
  "TRUCK",
];
export const ROLES: readonly Role[] = ["PASSENGER", "DRIVER", "ADMIN"];
export const KYC_STATUSES: readonly KycStatus[] = ["UNDER_REVIEW", "REJECTED", "NOT_UPLOADED", "VERIFIED"];
export const PAYMENT_STATUSES: readonly PaymentStatus[] = ["PENDING", "PAID", "FAILED", "REFUNDED"];
export const ZONE_KINDS: readonly ZoneKind[] = ["SURGE", "DEMAND", "NO_SERVICE", "PICKUP_POINT"];
export const AUDIENCES: readonly AnnouncementAudience[] = ["ALL", "PASSENGER", "DRIVER"];
export const PLAN_PERIODS: readonly PlanPeriod[] = ["DAILY", "WEEKLY", "MONTHLY"];
/** Documents drivers upload for review. The licence and Aadhaar are checked by Didit (identity check). */
export const KYC_DOC_TYPES: readonly KycDocType[] = ["VEHICLE_RC", "INSURANCE"];

/** A page of results (admin.types.ts). */
export interface Paged<T> {
  readonly items: T[];
  readonly total: number;
  readonly page: number;
  readonly pageSize: number;
}

export interface User {
  readonly id: string;
  readonly phone: string;
  readonly name: string | null;
  readonly email: string | null;
  readonly gender: Gender | null;
  readonly role: Role;
  readonly preferWomenDriver: boolean;
  readonly autoShareTrips: boolean;
  readonly isBlocked?: boolean;
  readonly blockedReason?: string | null;
  readonly identityStatus?: IdentityStatus;
  readonly identityVerifiedAt?: string | null;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** One Didit session. Only the last 4 digits of each document number are kept. */
export interface IdentityVerification {
  readonly id: string;
  readonly purpose: "DRIVER" | "RIDER";
  readonly sessionId: string;
  readonly status: IdentityStatus;
  /** Didit's own status ("Approved", "In Review", "Kyc Expired"…). */
  readonly providerStatus: string;
  readonly documentType: string | null;
  readonly documentLast4: string | null;
  readonly documents: { type: string; last4: string | null }[] | null;
  readonly fullName: string | null;
  readonly dateOfBirth: string | null;
  readonly warnings: string[] | null;
  readonly decidedAt: string | null;
  readonly createdAt: string;
}

/** GET /admin/passengers item. */
export interface Passenger extends User {
  readonly _count: { readonly trips: number };
}

export interface KycDocument {
  readonly id: string;
  readonly driverId: string;
  readonly type: KycDocType;
  readonly status: KycStatus;
  readonly rejectReason: string | null;
  readonly fileUrl: string | null;
  readonly updatedAt: string;
}

export interface Plan {
  readonly id: string;
  readonly vehicleKind: VehicleKind;
  readonly period: PlanPeriod;
  readonly price: number;
  readonly isActive: boolean;
}

export interface Payment {
  readonly id: string;
  readonly subscriptionId: string;
  readonly amount: number;
  readonly status: PaymentStatus;
  readonly provider: string;
  readonly providerRef: string | null;
  readonly createdAt: string;
}

export interface Subscription {
  readonly id: string;
  readonly driverId: string;
  readonly planId: string;
  readonly status: SubscriptionStatus;
  readonly startsAt: string;
  readonly endsAt: string;
  readonly upiApp: string | null;
  readonly autopay: boolean;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly plan: Plan;
  readonly payments?: Payment[];
}

export interface DriverBase {
  readonly id: string;
  readonly userId: string;
  readonly workType: WorkType;
  readonly vehicleKind: VehicleKind;
  readonly vehicleModel: string;
  readonly vehicleColor: string;
  readonly plate: string;
  readonly upiId: string;
  readonly rating: number;
  readonly ridesCount: number;
  readonly status: DriverStatus;
  readonly isOnline: boolean;
  /** Profile photo riders see (stored file; the admin opens it at /files/<name>). */
  readonly photoFile?: string | null;
  readonly photoUpdatedAt?: string | null;
  /** Live selfie from the approved Didit check (the reference photos are matched against). */
  readonly selfieFile?: string | null;
  /** A new photo with an unclear face match, waiting for an admin. */
  readonly pendingPhotoFile?: string | null;
  readonly photoMatchScore?: number | null;
  readonly photoRejectReason?: string | null;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** GET /admin/drivers item: latest subscription only. */
export interface Driver extends DriverBase {
  readonly user: User;
  readonly documents: KycDocument[];
  readonly subscriptions: Subscription[];
}

/** GET /admin/drivers/:id: all subscriptions with payments, last 20 trips. */
/** Why a driver was paused (API `DriverBlockReason`). */
export type DriverBlockReason = "CANCELLATION_RATE";

/** A temporary pause of a driver (too many cancellations); lifted early when [liftedAt] is set. */
export interface DriverBlock {
  readonly id: string;
  readonly driverId: string;
  readonly reason: DriverBlockReason;
  readonly fromAt: string;
  readonly untilAt: string;
  readonly liftedBy: string | null;
  readonly liftedAt: string | null;
  readonly details: { readonly cancelled?: number; readonly assigned?: number; readonly rate?: number } | null;
}

/** The driver's cancellation rate now (7 days, restarting after a pause; trips/driver-blocks.service.ts). */
export interface DriverCancelRate {
  readonly since: string;
  readonly cancelled: number;
  readonly assigned: number;
  readonly rate: number;
  readonly level: "OK" | "NUDGE" | "BLOCK";
  readonly blockedUntil: string | null;
  readonly minTrips: number;
  readonly nudgeAt: number;
  readonly blockAt: number;
}

/** GET /admin/drivers/:id/offer-stats: offers over the last 7 days, as dispatch ranking uses them. */
export interface DriverOfferStats {
  readonly days: number;
  readonly offered: number;
  readonly accepted: number;
  readonly declined: number;
  /** Let the offer run out. */
  readonly ignored: number;
  /** Cancelled after accepting, the driver's fault. */
  readonly cancelled: number;
  /** accepted ÷ answered offers (null without answers). */
  readonly acceptRate: number | null;
  /** Ranking uses the record from minOffers offers; below that the driver is neutral. */
  readonly isRanked: boolean;
  readonly minOffers: number;
}

/** A passenger's cancellations over the last 30 days (shown only; passengers are never blocked). */
export interface PassengerCancelRate {
  readonly since: string;
  readonly booked: number;
  readonly cancelled: number;
  readonly atFault: number;
  readonly rate: number;
  readonly faultRate: number;
}

export interface DriverDetail extends Driver {
  readonly trips: TripBase[];
  /** Pauses, newest first (up to 20), and the rate now. */
  readonly blocks?: DriverBlock[];
  readonly cancelRate?: DriverCancelRate;
  readonly blockedUntil?: string | null;
  /** Newest first (up to 5). */
  readonly user: User & { readonly identityChecks: IdentityVerification[] };
}

/** Itemised quote stored on the trip (fare engine output). */
export interface FareBreakdown {
  readonly base: number;
  readonly distanceCharge: number;
  readonly timeCharge: number;
  readonly minFareTopUp: number;
  readonly subtotal: number;
  readonly multiplier?: number;
  readonly peakCharge: number;
  /** Waiting at the pickup past the free minutes (set when the ride starts; never surged). */
  readonly waitingCharge?: number;
  /** The waiting terms quoted with the fare. */
  readonly freeWaitMin?: number;
  readonly waitPerMin?: number;
  readonly waitMaxCharge?: number;
  /** The passenger's earlier cancellation fee, added to this completed ride (collected by its driver). */
  readonly previousCancellationFee?: number;
  /** What the rider added while nobody had taken the trip ("+₹20"); goes to the driver. */
  readonly extra?: number;
  readonly total: number;
  readonly distanceKm?: number;
  readonly durationMin?: number;
  readonly vehicleKind?: VehicleKind;
}

export interface TripBase {
  readonly id: string;
  readonly kind: TripKind;
  readonly status: TripStatus;
  readonly passengerId: string;
  readonly driverId: string | null;
  readonly vehicleKind: VehicleKind;
  readonly pickupName: string;
  readonly pickupAddr: string;
  readonly pickupLat: number;
  readonly pickupLng: number;
  readonly dropName: string;
  readonly dropAddr: string;
  readonly dropLat: number;
  readonly dropLng: number;
  readonly distanceKm: number;
  readonly durationMin: number;
  readonly fare: Partial<FareBreakdown> | null;
  readonly fareTotal: number;
  readonly otp: string;
  readonly paymentMode: PaymentMode;
  readonly parcel: Record<string, unknown> | null;
  readonly payer: ParcelPayer | null;
  readonly rating: number | null;
  /** Free-text note with the cancel (older apps sent only this). */
  readonly cancelReason: string | null;
  /** Who cancelled (also SYSTEM on NO_DRIVERS), the reason code and when. */
  readonly cancelledBy?: CancelledBy | null;
  readonly cancelCode?: CancelCode | null;
  readonly cancelledAt?: string | null;
  /** Butterfly: women drivers first (PREFERRED) or only (ONLY). */
  readonly womenDriver?: "NONE" | "PREFERRED" | "ONLY";
  /** Booked for someone else ("Who's riding?"): the driver met and called this person. */
  readonly riderName?: string | null;
  readonly riderPhone?: string | null;
  readonly riderIsWoman?: boolean;
  /** Driver's distance from the pickup at "Arrived", and the reason given when outside the radius. */
  readonly arrivedDistanceM?: number | null;
  readonly arrivedFarReason?: string | null;
  /** Distance from the drop when the trip ended, and the reason when outside the radius. */
  readonly endDistanceM?: number | null;
  readonly endFarReason?: string | null;
  readonly createdAt: string;
  readonly assignedAt: string | null;
  readonly arrivedAt?: string | null;
  /** From then the driver may cancel as a passenger no-show. */
  readonly noShowAt?: string | null;
  /** Straight-line metres from the driver to the pickup at accept. */
  readonly acceptDistanceM?: number | null;
  /** Flagged for an admin: a trip timeout (still running far past its estimate) or the fare sanity checks at
   * completion (mock GPS, distance far from the quote with a stop outside its radius, no measurable distance). */
  readonly needsReview?: boolean;
  readonly reviewNote?: string | null;
  /** Recorded GPS path: metres driven on the ride (null when not measurable) and to the pickup. */
  readonly actualDistanceM?: number | null;
  readonly approachDistanceM?: number | null;
  /** The ride's path, Google-encoded (trip page only; not in the list). */
  readonly pathPolyline?: string | null;
  /** The quoted road route (from the booking's Routes call), Google-encoded; null without Google. Trip page only. */
  readonly routePolyline?: string | null;
  readonly gpsPoints?: number;
  readonly gpsMockCount?: number;
  readonly distanceCalcFailed?: boolean;
  readonly reassignCount?: number;
  readonly startedAt: string | null;
  readonly endedAt: string | null;
}

/** GET /admin/trips item. */
export interface Trip extends TripBase {
  readonly passenger: User;
  readonly driver: (DriverBase & { readonly user: User }) | null;
  /** List only: the latest cancellation's verdict. */
  readonly cancellations?: readonly Pick<TripCancellation, "fault" | "faultRule" | "reassigned">[];
}

/** One cancel of a trip (a driver's cancel that sent it back to searching is kept here too). */
export interface TripCancellation {
  readonly id: string;
  readonly driverId: string | null;
  readonly by: CancelledBy;
  readonly code: CancelCode;
  readonly note: string | null;
  readonly fromStatus: TripStatus;
  readonly reassigned: boolean;
  /** fault === "DRIVER" (counted in the driver's cancellation rate). */
  readonly isDriverFault: boolean;
  /** Verdict from the signals, the rule that decided, and the signals (trips/cancel-fault.ts). */
  readonly fault?: CancelFault;
  readonly faultRule?: string | null;
  readonly signals?: Record<string, unknown> | null;
  readonly createdAt: string;
  readonly driver: { readonly id: string; readonly plate: string; readonly user: { readonly name: string | null } } | null;
}

/** GET /admin/trips/:id. */
export interface TripDetail extends Trip {
  readonly tickets: SupportTicketBase[];
  readonly cancellations?: TripCancellation[];
  /** Safety: SOS alerts and events (long stops, deviations, check-ins), newest first. */
  readonly sos?: SosRecord[];
  readonly safetyEvents?: SafetyEvent[];
}

export interface SupportTicketBase {
  readonly id: string;
  readonly userId: string;
  readonly tripId: string | null;
  readonly topic: string;
  readonly description: string;
  readonly status: TicketStatus;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export type DueStatus = "PENDING" | "APPLIED";
export const DUE_STATUSES: readonly DueStatus[] = ["PENDING", "APPLIED"];

/** GET /admin/cancellation-dues item: a passenger's cancellation fee owed to a driver (report only, no settlement). */
export interface CancellationDue {
  readonly id: string;
  readonly amount: number;
  readonly status: DueStatus;
  readonly createdAt: string;
  readonly appliedAt: string | null;
  readonly passenger: { readonly id: string; readonly name: string | null; readonly phone: string };
  readonly owedTo: { readonly id: string; readonly plate: string; readonly user: { readonly name: string | null; readonly phone: string } };
  /** The cancelled trip. */
  readonly trip: { readonly id: string; readonly createdAt: string; readonly cancelledAt: string | null; readonly pickupName: string };
  /** The ride whose fare collected it; its driver took the cash. */
  readonly appliedTrip: {
    readonly id: string;
    readonly endedAt: string | null;
    readonly driver: { readonly id: string; readonly plate: string; readonly user: { readonly name: string | null; readonly phone: string } } | null;
  } | null;
}

/** GET /admin/tickets item. */
export interface SupportTicket extends SupportTicketBase {
  readonly user: User;
  readonly trip: TripBase | null;
}

/** GET /admin/stats. */
export interface AdminStats {
  readonly drivers: {
    readonly total: number;
    readonly pending: number;
    readonly approved: number;
    readonly rejected: number;
    readonly onHold: number;
    readonly online: number;
  };
  readonly passengers: number;
  readonly trips: {
    readonly today: number;
    readonly active: number;
    readonly completedToday: number;
    readonly cancelledToday: number;
    readonly faresToday: number;
  };
  readonly revenue: {
    readonly paidThisMonth: number;
    readonly activeSubscriptions: number;
    readonly trialSubscriptions: number;
  };
  readonly openTickets: number;
  readonly tripsLast7Days: { readonly date: string; readonly count: number }[];
}

/** POST /auth/verify. */
export interface LoginResult {
  readonly accessToken: string;
  readonly isNewUser: boolean;
  readonly user: User;
  readonly driverId?: string;
}

/** Error body from the API's AllExceptionsFilter. */
export interface ApiErrorBody {
  readonly statusCode: number;
  readonly error: string;
  readonly message: string | string[];
}

// ---------------------------------------------------------------------------------------------------------------
// Cities, zones, fares (admin-cities.controller.ts)

export interface Zone {
  readonly id: string;
  readonly cityId: string;
  readonly name: string;
  readonly kind: ZoneKind;
  readonly cells: string[];
  readonly surgeMultiplier: number;
  readonly color: string;
  readonly isActive: boolean;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface City {
  readonly id: string;
  readonly name: string;
  readonly state: string;
  readonly centerLat: number;
  readonly centerLng: number;
  readonly h3Resolution: number;
  readonly serviceCells: string[];
  readonly isActive: boolean;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** GET /admin/cities item. */
export interface CityListItem extends City {
  readonly _count: { readonly zones: number };
}

export interface CityFareRule {
  readonly id: string;
  readonly cityId: string;
  readonly vehicleKind: VehicleKind;
  readonly base: number;
  readonly perKm: number;
  readonly perMin: number;
  readonly minFare: number;
  /** Waiting charge per started minute (null = the built-in rate). */
  readonly waitPerMin: number | null;
  readonly isActive: boolean;
  readonly updatedAt: string;
}

/** GET /admin/cities/:id. */
export interface CityDetail extends City {
  readonly zones: Zone[];
  readonly fareRules: CityFareRule[];
}

/** GET /admin/cities/:id/fares item: the city's override or the built-in default. */
export interface CityFare {
  readonly vehicleKind: VehicleKind;
  readonly base: number;
  readonly perKm: number;
  readonly perMin: number;
  readonly minFare: number;
  /** Waiting charge per started minute after the free minutes (the built-in rate when the city has none). */
  readonly waitPerMin: number;
  readonly isActive: boolean;
  readonly isDefault: boolean;
}

// ---------------------------------------------------------------------------------------------------------------
// Users and KYC queue (admin-users.controller.ts)

/** GET /admin/users item. */
export interface AdminUser extends User {
  readonly driver: { readonly id: string; readonly status: DriverStatus; readonly vehicleKind: VehicleKind; readonly plate: string } | null;
  readonly _count: { readonly trips: number; readonly tickets: number };
}

export interface EmergencyContact {
  readonly id: string;
  readonly userId: string;
  readonly name: string;
  readonly relation: string;
  readonly phone: string;
}

export interface SavedPlace {
  readonly id: string;
  readonly userId: string;
  readonly label: string;
  readonly kind: string;
  readonly name: string;
  readonly address: string;
  readonly lat: number;
  readonly lng: number;
  readonly note: string | null;
}

/** GET /admin/users/:id. */
export interface UserDetail extends User {
  readonly driver: (DriverBase & { readonly documents: KycDocument[] }) | null;
  readonly emergencyContacts: EmergencyContact[];
  readonly savedPlaces: SavedPlace[];
  readonly trips: TripBase[];
  readonly tickets: SupportTicketBase[];
  readonly cancelRate?: PassengerCancelRate;
}

/** GET /admin/kyc item. */
export interface KycQueueItem extends KycDocument {
  readonly driver: DriverBase & {
    readonly user: { readonly id: string; readonly name: string | null; readonly phone: string; readonly identityStatus?: IdentityStatus };
  };
}

// ---------------------------------------------------------------------------------------------------------------
// Live map, payments, announcements, settings, audit (admin-ops.controller.ts)

export interface LiveDriver {
  readonly driverId: string;
  readonly name: string | null;
  readonly vehicleKind: VehicleKind;
  readonly plate: string;
  readonly lat: number;
  readonly lng: number;
  readonly activeTripId: string | null;
}

export interface LiveTrip {
  readonly id: string;
  readonly kind: TripKind;
  readonly status: TripStatus;
  readonly vehicleKind: VehicleKind;
  readonly pickupName: string;
  readonly pickupLat: number;
  readonly pickupLng: number;
  readonly dropName: string;
  readonly dropLat: number;
  readonly dropLng: number;
  readonly fareTotal: number;
  readonly driverId: string | null;
  readonly createdAt: string;
}

/** GET /admin/live. */
export interface LiveData {
  readonly drivers: LiveDriver[];
  readonly trips: LiveTrip[];
}

/** GET /admin/payments item. */
export interface PaymentRow extends Payment {
  readonly subscription: Omit<Subscription, "payments"> & {
    readonly driver: DriverBase & { readonly user: { readonly name: string | null; readonly phone: string } };
  };
}

export interface Announcement {
  readonly id: string;
  readonly audience: AnnouncementAudience;
  readonly title: string;
  readonly body: string;
  readonly cityId: string | null;
  readonly isActive: boolean;
  readonly startsAt: string;
  readonly endsAt: string | null;
  readonly createdAt: string;
}

/** GET/PUT /admin/settings (settings.defaults.ts). */
export interface Settings {
  readonly currentMultiplier: number;
  readonly maxMultiplier: number;
  readonly searchRadiusKm: number;
  /** The search widens up to this while nobody accepts. */
  readonly maxSearchRadiusKm: number;
  /** Seconds to widen from searchRadiusKm to maxSearchRadiusKm. */
  readonly searchExpandSeconds: number;
  readonly offerSeconds: number;
  /** Requests one driver can have open at once (stacked in the app). */
  readonly maxOpenOffers: number;
  readonly maxCandidates: number;
  /** A driver cancel before pickup sends the trip back to searching this many times. */
  readonly maxReassigns: number;
  /** Trip timeouts (trip-timeouts.ts): not moving, no-show wait, stuck trips, never-started cap. */
  readonly notMovingMinMin: number;
  readonly notMovingEtaFactor: number;
  readonly notMovingMinProgressM: number;
  readonly notMovingRecheckMin: number;
  readonly noShowWaitMin: number;
  /** Waiting charge: free minutes after "Arrived", then the vehicle's waitPerMin per started minute, up to the cap. */
  readonly freeWaitMin: number;
  readonly waitMaxCharge: number;
  /** Cancellation fee (off by default): owed after a passenger cancels once the driver arrived and waited. */
  readonly cancellationFeeEnabled: boolean;
  readonly cancellationFee: number;
  /** Driver cancellation rate (7 days): judged from minTrips assigned trips, nudge / pause thresholds, pause hours. */
  readonly cancelRateMinTrips: number;
  readonly cancelRateNudge: number;
  readonly cancelRateBlock: number;
  readonly cancelBlockHours: number;
  readonly cancelBlockRepeatHours: number;
  /** Dispatch ranking: eta × (1 + wAccept·(1 − accept) + wCancel·cancel) − idle bonus (up to a share of the ETA). */
  readonly rankEnabled: boolean;
  readonly rankWeightAccept: number;
  readonly rankWeightCancel: number;
  /** Cap on the record's penalty (0.5 → at most ETA × 1.5). */
  readonly rankMaxPenalty: number;
  readonly rankIdleMaxBoost: number;
  readonly rankIdleFullMin: number;
  readonly rankMinOffers: number;
  readonly stuckTripMinMin: number;
  readonly stuckDurationFactor: number;
  readonly pickupHardCapMin: number;
  readonly trialDays: number;
  readonly graceDays: number;
  /** Bookings are collected this long, then assigned together (dispatch batching). */
  readonly batchWindowMs: number;
  /** Rank candidate drivers by road ETA (Google Routes) instead of a straight-line estimate. */
  readonly useRoadEta: boolean;
  /** Live surge from demand vs free drivers per res-7 hexagon. */
  readonly dynamicSurgeEnabled: boolean;
  /** multiplier = 1 + sensitivity × (ratio − 1). */
  readonly surgeSensitivity: number;
  /** Minutes of bookings counted as current demand. */
  readonly demandWindowMin: number;
  /** Below this many requests in a hex there is no surge. */
  readonly surgeMinRequests: number;
  /** Learned hex-to-hex ETA is used once a pair has this many trips (0 = off). */
  readonly historicalEtaMinTrips: number;
  /** Safety: push every admin's phone on an SOS. */
  readonly sosAdminAlert: boolean;
  /** Stop during a ride: within stopRadiusM for stopMinutes (away from pickup and drop) → "Is everything OK?", once per stopDedupeMin. */
  readonly stopRadiusM: number;
  readonly stopMinutes: number;
  readonly stopDedupeMin: number;
  /** Route deviation (metres off the quoted route, 3 fixes in a row) and the night window in IST (start–end hour). */
  readonly deviationM: number;
  readonly nightStartHour: number;
  readonly nightEndHour: number;
  readonly supportPhone: string;
  /** Off = free app: no plan screens and no plan check when going online. */
  readonly driverPlansEnabled: boolean;
  /** Contribute page (both apps). */
  readonly contributeUpiId: string;
  readonly contributePayeeName: string;
  readonly contributeNote: string;
  /** Monthly running cost in rupees; the apps show the total and the non-zero parts. */
  readonly costServersInr: number;
  readonly costMapsInr: number;
  readonly costSmsInr: number;
  readonly costOtherInr: number;
}

/** Settings as returned by the API: the known keys plus anything newer (rendered in "Other"). */
export type SettingsRecord = Settings & Record<string, number | boolean | string>;

export interface AuditLog {
  readonly id: string;
  readonly actorId: string;
  readonly action: string;
  readonly entity: string;
  readonly entityId: string | null;
  readonly data: unknown;
  readonly createdAt: string;
}

/** Public GET /cities/:id/service-area. */
export interface ServiceArea {
  readonly id: string;
  readonly name: string;
  readonly resolution: number;
  readonly cells: string[];
  readonly zones: Pick<Zone, "id" | "name" | "kind" | "cells" | "surgeMultiplier" | "color">[];
}

// ---------------------------------------------------------------------------------------------------------------
// Heatmap (admin-heatmap.service.ts)

export type HeatmapMetric = "pickups" | "drops" | "unmet" | "fares";
export const HEATMAP_METRICS: readonly HeatmapMetric[] = ["pickups", "drops", "unmet", "fares"];

export interface HeatCell {
  readonly cell: string;
  readonly value: number;
  /** value / max, 0–1. */
  readonly intensity: number;
}

/** GET /admin/heatmap. */
export interface Heatmap {
  readonly metric: HeatmapMetric;
  readonly resolution: number;
  readonly total: number;
  readonly max: number;
  readonly from: string;
  readonly to: string;
  readonly cells: HeatCell[];
}

export interface HeatmapQuery {
  readonly metric?: HeatmapMetric;
  readonly from?: string;
  readonly to?: string;
  readonly kind?: TripKind;
  readonly vehicleKind?: VehicleKind;
  readonly hourFrom?: number;
  readonly hourTo?: number;
  readonly resolution?: number;
}

// ---------------------------------------------------------------------------------------------------------------
// Live demand / surge (geo/demand.service.ts) and learned travel speeds (geo/hex-stats.service.ts)

export type DemandLevel = "normal" | "busy" | "high";

export interface DemandCell {
  readonly cell: string;
  readonly lat: number;
  readonly lng: number;
  readonly requests: number;
  readonly freeDrivers: number;
  readonly ratio: number;
  /** Smoothed across ring-1 neighbours. */
  readonly multiplier: number;
  readonly level: DemandLevel;
}

/** GET /admin/demand. */
export interface DemandSnapshot {
  readonly at: string;
  readonly windowMin: number;
  readonly cells: DemandCell[];
}

export interface HexStatRow {
  readonly fromCell: string;
  readonly toCell: string;
  /** IST hour 0–23. */
  readonly hour: number;
  /** H3 resolution of both cells (9 street, 8 neighbourhood, 7 district). */
  readonly res: HexStatRes;
  readonly trips: number;
  readonly avgSpeedKmh: number;
  readonly avgDurationMin: number;
  readonly updatedAt?: string;
}

export const HEX_STAT_RES = [9, 8, 7] as const;
export type HexStatRes = (typeof HEX_STAT_RES)[number];

/** GET /admin/hex-stats?res=9|8|7. */
export interface HexStats {
  readonly res: HexStatRes;
  /** Rows at [res]. */
  readonly rows: number;
  readonly byRes: Record<HexStatRes, number>;
  readonly lastRun: string | null;
  readonly top: HexStatRow[];
  /** All rows at res: speed per IST hour. */
  readonly byHour: readonly { hour: number; speed: number; trips: number }[];
  /** Speed of trips leaving each hex (hour filter applies). */
  readonly areas: readonly { cell: string; speed: number; trips: number }[];
  readonly accuracy: EtaAccuracy;
}

export type EtaSource = "res9" | "res8" | "res7" | "all-day" | "fallback";

export interface EtaAccuracyStats {
  readonly trips: number;
  readonly maeMin: number;
  readonly mapePct: number;
  /** Mean (predicted − actual) minutes: positive = ETAs too long. */
  readonly biasMin: number;
}

/** Recent trips replayed through the learned speeds. */
export interface EtaAccuracy extends EtaAccuracyStats {
  readonly days: number;
  readonly sources: readonly (EtaAccuracyStats & { source: EtaSource })[];
}

export type HexStatsSort = "busiest" | "slowest" | "fastest";
