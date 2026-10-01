"use server";

import { revalidatePath } from "next/cache";

import { redirect } from "next/navigation";

import { ApiError, adminApi, type AnnouncementInput, type CityInput, type FareInput, type ZoneInput } from "@/lib/api";
import { validateSettings, type SettingsInput } from "@/lib/validation";
import {
  AUDIENCES,
  DRIVER_STATUSES,
  KYC_DOC_TYPES,
  ROLES,
  TICKET_STATUSES,
  VEHICLE_KINDS,
  ZONE_KINDS,
  type City,
  type DriverStatus,
  type KycDocType,
  type Role,
  type TicketStatus,
  type VehicleKind,
} from "@/lib/types";

export type ActionResult<T = undefined> = { ok: true; message: string; data?: T } | { ok: false; error: string };

/** Runs an API mutation; API errors become a toast message, redirects (401) still propagate. */
async function run<T>(fn: () => Promise<T>, message: string | ((data: T) => string), paths: string[]): Promise<ActionResult<T>> {
  let data: T;
  try {
    data = await fn();
  } catch (e) {
    if (e instanceof ApiError) return { ok: false, error: e.message };
    throw e;
  }
  for (const p of paths) revalidatePath(p);
  return { ok: true, message: typeof message === "function" ? message(data) : message, data };
}

/** Drops the API payload (keeps Server Action responses small). */
function plain<T>(res: ActionResult<T>): ActionResult {
  return res.ok ? { ok: true, message: res.message } : { ok: false, error: res.error };
}

/** Approve, hold, reject or reactivate. A reason (hold: optional, reject: required) is pushed to the driver. */
export async function setDriverStatus(driverId: string, status: DriverStatus, reason?: string): Promise<ActionResult> {
  if (!DRIVER_STATUSES.includes(status)) return { ok: false, error: "Unknown status" };
  const trimmed = reason?.trim() || undefined;
  if (status === "REJECTED" && !trimmed) return { ok: false, error: "Add a reason the driver will see" };
  if (trimmed && (trimmed.length < 3 || trimmed.length > 200)) return { ok: false, error: "Reason must be 3–200 characters" };
  const label = { APPROVED: "Driver approved", ON_HOLD: "Driver put on hold", REJECTED: "Driver rejected", PENDING: "Driver moved to pending" }[status];
  return plain(
    await run(() => adminApi.setDriverStatus(driverId, status, trimmed), label, [`/drivers/${driverId}`, "/drivers", "/drivers/approvals", "/"]),
  );
}

/** Approves several ready drivers (POST /admin/drivers/approve); drivers not ready are skipped and counted. */
export async function approveDrivers(ids: string[]): Promise<ActionResult<{ approved: number; skipped: number }>> {
  const unique = [...new Set(ids)].filter(Boolean);
  if (unique.length === 0) return { ok: false, error: "Select at least one driver" };
  if (unique.length > 50) return { ok: false, error: "Approve at most 50 drivers at a time" };
  return run(
    async () => {
      const r = await adminApi.approveDrivers(unique);
      return { approved: r.approved.length, skipped: r.skipped.length };
    },
    (r) => `${r.approved} driver${r.approved === 1 ? "" : "s"} approved${r.skipped ? `, ${r.skipped} skipped (not ready or already decided)` : ""}`,
    ["/drivers/approvals", "/drivers", "/"],
  );
}

/** Settings › driverAutoApprove, switched from the Approvals page. */
export async function setAutoApprove(isOn: boolean): Promise<ActionResult> {
  return plain(
    await run(
      () => adminApi.updateSettings({ driverAutoApprove: isOn }),
      isOn ? "Auto-approval on: drivers are approved once every check passes" : "Manual approval on: ready drivers wait for you",
      ["/drivers/approvals", "/settings"],
    ),
  );
}

/** Ends the driver's cancellation pause now (POST /admin/drivers/:id/lift-block, audit logged). */
export async function liftDriverBlock(driverId: string): Promise<ActionResult> {
  return plain(await run(() => adminApi.liftDriverBlock(driverId), "Pause lifted. The driver can go online again", [`/drivers/${driverId}`, "/drivers"]));
}

export async function reviewDocument(
  driverId: string,
  type: KycDocType,
  status: "VERIFIED" | "REJECTED",
  reason?: string,
): Promise<ActionResult> {
  if (!KYC_DOC_TYPES.includes(type)) return { ok: false, error: "Unknown document" };
  const trimmed = reason?.trim();
  if (status === "REJECTED" && (!trimmed || trimmed.length < 3)) return { ok: false, error: "Add a reason (at least 3 characters)" };
  return plain(await run(
    () => adminApi.reviewDocument(driverId, type, status, status === "REJECTED" ? trimmed : undefined),
    status === "VERIFIED" ? "Document verified" : "Document rejected",
    [`/drivers/${driverId}`, "/drivers", "/drivers/approvals", "/kyc", "/"],
  ));
}

export async function reviewPhoto(driverId: string, isApproved: boolean, reason?: string): Promise<ActionResult> {
  const trimmed = reason?.trim();
  if (!isApproved && (!trimmed || trimmed.length < 3)) return { ok: false, error: "Add a reason (at least 3 characters)" };
  return plain(await run(
    () => adminApi.reviewPhoto(driverId, isApproved, isApproved ? undefined : trimmed),
    isApproved ? "Photo approved" : "Photo rejected",
    [`/drivers/${driverId}`, "/drivers", "/drivers/approvals"],
  ));
}

export async function updatePlan(planId: string, data: { price?: number; isActive?: boolean }): Promise<ActionResult> {
  if (data.price !== undefined && (!Number.isInteger(data.price) || data.price < 0 || data.price > 100_000)) {
    return { ok: false, error: "Price must be a whole number between ₹0 and ₹1,00,000" };
  }
  const message = data.price !== undefined ? "Price updated" : data.isActive ? "Plan activated" : "Plan deactivated";
  return plain(await run(() => adminApi.updatePlan(planId, data), message, ["/plans"]));
}

export async function clearTripReview(tripId: string, note?: string): Promise<ActionResult> {
  const trimmed = note?.trim() || undefined;
  if (trimmed && trimmed.length > 300) return { ok: false, error: "Keep the note under 300 characters" };
  return plain(await run(() => adminApi.reviewTrip(tripId, false, trimmed), "Marked as reviewed", [`/trips/${tripId}`, "/trips"]));
}

export async function setTicketStatus(ticketId: string, status: TicketStatus): Promise<ActionResult> {
  if (!TICKET_STATUSES.includes(status)) return { ok: false, error: "Unknown status" };
  return plain(await run(() => adminApi.setTicketStatus(ticketId, status), "Ticket updated", ["/support", "/"]));
}

// Cities, service areas, zones, fares ----------------------------------------------------------------------------

const SLUG = /^[a-z0-9-]{2,40}$/;

export async function createCity(input: CityInput): Promise<ActionResult> {
  if (!SLUG.test(input.id)) return { ok: false, error: "Id must be a lowercase slug, e.g. tiruppur" };
  if (input.name.trim().length < 2 || input.state.trim().length < 2) return { ok: false, error: "Name and state are required" };
  if (!Number.isFinite(input.centerLat) || Math.abs(input.centerLat) > 90) return { ok: false, error: "Latitude must be between -90 and 90" };
  if (!Number.isFinite(input.centerLng) || Math.abs(input.centerLng) > 180) return { ok: false, error: "Longitude must be between -180 and 180" };
  if (input.h3Resolution !== undefined && (input.h3Resolution < 7 || input.h3Resolution > 9)) return { ok: false, error: "H3 resolution must be 7, 8 or 9" };
  if (input.radiusKm !== undefined && (input.radiusKm < 0 || input.radiusKm > 60)) return { ok: false, error: "Radius must be 0–60 km" };
  return plain(await run(() => adminApi.createCity({ ...input, name: input.name.trim(), state: input.state.trim() }), (c) => `${c.name} created`, ["/cities", "/"]));
}

export async function updateCity(
  id: string,
  data: Partial<Pick<City, "name" | "state" | "centerLat" | "centerLng" | "isActive">>,
): Promise<ActionResult> {
  const message = data.isActive === undefined ? "City saved" : data.isActive ? "City activated" : "City deactivated";
  const res = await run(() => adminApi.updateCity(id, data), message, ["/cities", `/cities/${id}`]);
  return plain(res);
}

export async function deleteCity(id: string): Promise<ActionResult> {
  const res = await run(() => adminApi.deleteCity(id), "City deleted", ["/cities", "/"]);
  if (!res.ok) return res;
  redirect("/cities");
}

export async function saveServiceCells(id: string, cells: string[]): Promise<ActionResult<{ count: number; rejected: string[] }>> {
  if (cells.length > 20_000) return { ok: false, error: "At most 20,000 cells per city" };
  return run(
    async () => {
      const r = await adminApi.setServiceCells(id, cells);
      return { count: r.count, rejected: r.rejected.slice(0, 20) };
    },
    (r) => `Service area saved: ${r.count.toLocaleString("en-IN")} cells${r.rejected.length ? `, ${r.rejected.length} rejected` : ""}`,
    [`/cities/${id}`, "/cities"],
  );
}

function checkZone(input: Partial<ZoneInput>): string | null {
  if (input.name !== undefined && (input.name.trim().length < 2 || input.name.trim().length > 60)) return "Zone name must be 2–60 characters";
  if (input.kind !== undefined && !ZONE_KINDS.includes(input.kind)) return "Unknown zone kind";
  if (input.surgeMultiplier !== undefined && (input.surgeMultiplier < 1 || input.surgeMultiplier > 1.5)) return "Multiplier must be 1.0–1.5";
  if (input.color !== undefined && !/^#[0-9a-f]{6}$/i.test(input.color)) return "Colour must be a hex value like #F4511E";
  if (input.cells !== undefined && input.cells.length === 0) return "Paint at least one hexagon";
  if (input.cells !== undefined && input.cells.length > 5_000) return "A zone can have at most 5,000 cells";
  return null;
}

export async function createZone(cityId: string, input: ZoneInput): Promise<ActionResult> {
  const error = checkZone(input);
  if (error) return { ok: false, error };
  const res = await run(() => adminApi.createZone(cityId, { ...input, name: input.name.trim() }), (z) => `Zone “${z.name}” created`, [`/cities/${cityId}`, "/cities"]);
  return plain(res);
}

export async function updateZone(cityId: string, zoneId: string, input: Partial<ZoneInput>): Promise<ActionResult> {
  const error = checkZone(input);
  if (error) return { ok: false, error };
  const res = await run(() => adminApi.updateZone(zoneId, input), (z) => `Zone “${z.name}” saved`, [`/cities/${cityId}`]);
  return plain(res);
}

export async function deleteZone(cityId: string, zoneId: string): Promise<ActionResult> {
  const res = await run(() => adminApi.deleteZone(zoneId), "Zone deleted", [`/cities/${cityId}`, "/cities"]);
  return plain(res);
}

export async function setCityFare(cityId: string, kind: VehicleKind, input: FareInput): Promise<ActionResult> {
  if (!VEHICLE_KINDS.includes(kind)) return { ok: false, error: "Unknown vehicle" };
  const { base, perKm, perMin, minFare } = input;
  if (!Number.isInteger(base) || base < 0 || base > 10_000) return { ok: false, error: "Base fare must be a whole number, ₹0–₹10,000" };
  if (!Number.isFinite(perKm) || perKm < 0 || perKm > 500) return { ok: false, error: "Per km must be ₹0–₹500" };
  if (!Number.isFinite(perMin) || perMin < 0 || perMin > 100) return { ok: false, error: "Per minute must be ₹0–₹100" };
  if (!Number.isInteger(minFare) || minFare < 0 || minFare > 20_000) return { ok: false, error: "Minimum fare must be a whole number, ₹0–₹20,000" };
  const { waitPerMin } = input;
  if (waitPerMin !== undefined && (!Number.isInteger(waitPerMin) || waitPerMin < 0 || waitPerMin > 100)) {
    return { ok: false, error: "Waiting per minute must be a whole number, ₹0–₹100" };
  }
  const res = await run(() => adminApi.setFare(cityId, kind, input), "Fare saved", [`/cities/${cityId}`]);
  return plain(res);
}

export async function resetCityFare(cityId: string, kind: VehicleKind): Promise<ActionResult> {
  const res = await run(() => adminApi.resetFare(cityId, kind), "Fare reset to default", [`/cities/${cityId}`]);
  return plain(res);
}

// Users ----------------------------------------------------------------------------------------------------------

export async function setUserRole(userId: string, role: Role): Promise<ActionResult> {
  if (!ROLES.includes(role)) return { ok: false, error: "Unknown role" };
  const res = await run(() => adminApi.updateUser(userId, { role }), `Role changed to ${role.toLowerCase()}`, [`/users/${userId}`, "/users"]);
  return plain(res);
}

export async function setUserBlocked(userId: string, isBlocked: boolean, reason?: string): Promise<ActionResult> {
  const trimmed = reason?.trim();
  if (isBlocked && (!trimmed || trimmed.length < 3 || trimmed.length > 200)) return { ok: false, error: "Add a reason (3–200 characters)" };
  const res = await run(
    () => adminApi.updateUser(userId, isBlocked ? { isBlocked, blockedReason: trimmed } : { isBlocked }),
    isBlocked ? "User blocked" : "User unblocked",
    [`/users/${userId}`, "/users", "/"],
  );
  return plain(res);
}

// Announcements ----------------------------------------------------------------------------------------------------

export async function createAnnouncement(input: AnnouncementInput): Promise<ActionResult> {
  if (!AUDIENCES.includes(input.audience)) return { ok: false, error: "Pick an audience" };
  const title = input.title.trim();
  const body = input.body.trim();
  if (title.length < 3 || title.length > 80) return { ok: false, error: "Title must be 3–80 characters" };
  if (body.length < 3 || body.length > 500) return { ok: false, error: "Message must be 3–500 characters" };
  let endsAt: string | undefined;
  if (input.endsAt) {
    const d = new Date(input.endsAt);
    if (Number.isNaN(d.getTime())) return { ok: false, error: "Invalid end date" };
    if (d.getTime() <= Date.now()) return { ok: false, error: "End date must be in the future" };
    endsAt = d.toISOString();
  }
  const res = await run(
    () => adminApi.createAnnouncement({ audience: input.audience, title, body, cityId: input.cityId || undefined, endsAt }),
    "Announcement published",
    ["/announcements"],
  );
  return plain(res);
}

export async function setAnnouncementActive(id: string, isActive: boolean): Promise<ActionResult> {
  const res = await run(() => adminApi.setAnnouncementActive(id, isActive), isActive ? "Announcement shown" : "Announcement hidden", ["/announcements"]);
  return plain(res);
}

export async function deleteAnnouncement(id: string): Promise<ActionResult> {
  const res = await run(() => adminApi.deleteAnnouncement(id), "Announcement deleted", ["/announcements"]);
  return plain(res);
}

// Settings ---------------------------------------------------------------------------------------------------------

export async function saveSettings(input: SettingsInput): Promise<ActionResult> {
  const errors = validateSettings(input);
  const first = Object.values(errors)[0];
  if (first) return { ok: false, error: first };
  const res = await run(() => adminApi.updateSettings(input), "Settings saved", ["/settings", "/live"]);
  return plain(res);
}

// Learned travel speeds -----------------------------------------------------------------------------------------------

export async function rebuildHexStats(): Promise<ActionResult> {
  return plain(
    await run(() => adminApi.rebuildHexStats(), (r) => `Rebuilt: ${r.pairs.toLocaleString("en-IN")} hex-pair/hour rows from ${r.trips.toLocaleString("en-IN")} trips`, ["/travel-speeds"]),
  );
}

/** Someone is on this SOS (POST /admin/sos/:id/ack, audit logged). */
export async function acknowledgeSos(id: string, tripId: string): Promise<ActionResult> {
  return plain(await run(() => adminApi.acknowledgeSos(id), "SOS acknowledged", ["/safety", `/trips/${tripId}`]));
}

/** Closes an SOS as resolved or a false alarm, with a note (POST /admin/sos/:id/resolve, audit logged). */
export async function resolveSos(id: string, tripId: string, status: "RESOLVED" | "FALSE_ALARM", note?: string): Promise<ActionResult> {
  if (status !== "RESOLVED" && status !== "FALSE_ALARM") return { ok: false, error: "Unknown status" };
  const trimmed = note?.trim() || undefined;
  if (trimmed && trimmed.length > 500) return { ok: false, error: "Keep the note under 500 characters" };
  if (status === "RESOLVED" && !trimmed) return { ok: false, error: "Add a note: what happened and what you did" };
  return plain(await run(() => adminApi.resolveSos(id, status, trimmed), status === "RESOLVED" ? "SOS resolved" : "Marked as a false alarm", ["/safety", `/trips/${tripId}`]));
}
