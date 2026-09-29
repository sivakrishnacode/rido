// The public live-trip page (/track/<token>): the API's share view and what the page shows for it. Pure, so it can
// be unit-tested and used on the server and in the browser.
import { formatTime, vehicleLabel } from "./format";
import type { VehicleKind } from "./types";

type TripStatus =
  | "SEARCHING"
  | "NO_DRIVERS"
  | "DRIVER_ASSIGNED"
  | "DRIVER_ARRIVED"
  | "IN_PROGRESS"
  | "PICKED_UP"
  | "COMPLETED"
  | "DELIVERED"
  | "CANCELLED";

type Point = { lat: number; lng: number };

/** GET /v1/share/:token (apps/api/src/modules/safety/share.service.ts). */
export interface ShareView {
  readonly status: TripStatus;
  readonly kind: "RIDE" | "PARCEL";
  readonly isLive: boolean;
  readonly driver: { firstName: string; vehicleKind: VehicleKind; vehicleModel: string; vehicleColor: string; plate: string } | null;
  readonly location: (Point & { at: number | null }) | null;
  readonly pickup: Point & { name: string };
  readonly drop: Point & { name: string };
  readonly etaMin: number | null;
  readonly etaTo: "pickup" | "drop" | null;
  readonly expiresAt: string;
}

/** A read of the link: the view, or why there is none. */
export type ShareResult = { kind: "ok"; view: ShareView } | { kind: "ended" } | { kind: "not-found" } | { kind: "error"; message: string };

/** How often the page asks for a fresh position. */
export const TRACK_POLL_MS = 5_000;

const STATUS_LINE: Record<TripStatus, string> = {
  SEARCHING: "Finding a driver",
  NO_DRIVERS: "No driver was found",
  DRIVER_ASSIGNED: "Driver on the way to the pickup",
  DRIVER_ARRIVED: "Driver at the pickup",
  IN_PROGRESS: "On the way",
  PICKED_UP: "Parcel on the way",
  COMPLETED: "Arrived",
  DELIVERED: "Delivered",
  CANCELLED: "Trip cancelled",
};

/** What the page renders for [view] at [now] (epoch ms). */
export interface TrackModel {
  readonly title: string;
  readonly status: string;
  readonly isLive: boolean;
  /** "Selvam · Blue TVS Jupiter (Bike)". */
  readonly driverLine: string | null;
  readonly plate: string | null;
  /** "Arriving at the drop in about 12 min (4:52 pm)". */
  readonly etaLine: string | null;
  /** "Updated 20 s ago" / "Location not updated for 3 min". */
  readonly freshness: string | null;
  readonly isStale: boolean;
  readonly vehicle: Point | null;
  readonly pickup: Point & { name: string };
  readonly drop: Point & { name: string };
  /** Points the map should fit. */
  readonly fit: Point[];
}

/** A fix older than this is shown as stale ("not updated for …"). */
export const STALE_AFTER_MS = 60_000;

export function trackModel(view: ShareView, now: number): TrackModel {
  const d = view.driver;
  const vehicle = d ? [d.vehicleColor, d.vehicleModel].filter((s) => s.trim()).join(" ") : "";
  const driverLine = d ? `${d.firstName} · ${vehicle ? `${vehicle} (${vehicleLabel(d.vehicleKind)})` : vehicleLabel(d.vehicleKind)}` : null;
  const etaLine =
    view.etaMin !== null && view.etaTo
      ? `${view.etaTo === "drop" ? "Arriving at the drop" : "Reaching the pickup"} in about ${view.etaMin} min (${formatTime(new Date(now + view.etaMin * 60_000))})`
      : null;
  const at = view.location?.at ?? null;
  const age = at === null ? null : Math.max(0, now - at);
  const isStale = age !== null && age > STALE_AFTER_MS;
  const freshness =
    age === null ? null : isStale ? `Location not updated for ${Math.round(age / 60_000)} min` : `Updated ${Math.round(age / 1000)} s ago`;
  const loc = view.location ? { lat: view.location.lat, lng: view.location.lng } : null;
  const target = view.etaTo === "pickup" ? view.pickup : view.drop;
  return {
    title: `${view.kind === "PARCEL" ? "Tamil Taxi parcel" : "Tamil Taxi ride"} to ${view.drop.name}`,
    status: STATUS_LINE[view.status] ?? view.status,
    isLive: view.isLive,
    driverLine,
    plate: d?.plate ?? null,
    etaLine,
    freshness,
    isStale,
    vehicle: loc,
    pickup: view.pickup,
    drop: view.drop,
    fit: loc ? [loc, { lat: target.lat, lng: target.lng }] : [view.pickup, view.drop],
  };
}

/** The API's answer to GET /share/:token, as a [ShareResult]. */
export function shareResult(status: number, body: unknown): ShareResult {
  if (status === 200 && body && typeof body === "object") return { kind: "ok", view: body as ShareView };
  if (status === 410) return { kind: "ended" };
  if (status === 404) return { kind: "not-found" };
  if (status === 429) return { kind: "error", message: "Too many refreshes. Please wait a moment." };
  return { kind: "error", message: "Couldn't load the trip. Retrying…" };
}
