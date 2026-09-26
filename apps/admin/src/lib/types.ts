// Response shapes of the Rido admin API (apps/api/src/modules/admin, apps/api/prisma/schema.prisma).
// Dates arrive as ISO strings; money is whole rupees.

export type Role = "PASSENGER" | "DRIVER" | "ADMIN";
export type Gender = "FEMALE" | "MALE" | "PREFER_NOT_TO_SAY";
export type WorkType = "RIDES" | "DELIVERIES";
export type VehicleKind = "BIKE" | "AUTO" | "CAB" | "GOODS_BIKE" | "THREE_WHEELER" | "MINI_TRUCK" | "PICKUP" | "TRUCK";
export type DriverStatus = "PENDING" | "APPROVED" | "REJECTED" | "ON_HOLD";
export type KycDocType = "DRIVING_LICENCE" | "AADHAAR" | "VEHICLE_RC" | "INSURANCE" | "POLICE_VERIFICATION";
export type KycStatus = "NOT_UPLOADED" | "UNDER_REVIEW" | "VERIFIED" | "REJECTED";
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
export const KYC_DOC_TYPES: readonly KycDocType[] = [
  "DRIVING_LICENCE",
  "AADHAAR",
  "VEHICLE_RC",
  "INSURANCE",
  "POLICE_VERIFICATION",
];

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
  readonly createdAt: string;
  readonly updatedAt: string;
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
export interface DriverDetail extends Driver {
  readonly trips: TripBase[];
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
  readonly cancelReason: string | null;
  /** Driver's distance from the pickup at "Arrived", and the reason given when outside the radius. */
  readonly arrivedDistanceM?: number | null;
  readonly arrivedFarReason?: string | null;
  /** Distance from the drop when the trip ended, and the reason when outside the radius. */
  readonly endDistanceM?: number | null;
  readonly endFarReason?: string | null;
  readonly createdAt: string;
  readonly assignedAt: string | null;
  readonly startedAt: string | null;
  readonly endedAt: string | null;
}

/** GET /admin/trips item. */
export interface Trip extends TripBase {
  readonly passenger: User;
  readonly driver: (DriverBase & { readonly user: User }) | null;
}

/** GET /admin/trips/:id. */
export interface TripDetail extends Trip {
  readonly tickets: SupportTicketBase[];
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
}

/** GET /admin/kyc item. */
export interface KycQueueItem extends KycDocument {
  readonly driver: DriverBase & { readonly user: { readonly id: string; readonly name: string | null; readonly phone: string } };
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
  readonly offerSeconds: number;
  readonly maxCandidates: number;
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
