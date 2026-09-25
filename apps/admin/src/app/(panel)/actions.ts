"use server";

import { revalidatePath } from "next/cache";

import { redirect } from "next/navigation";

import { ApiError, adminApi, type AnnouncementInput, type CityInput, type FareInput, type ZoneInput } from "@/lib/api";
import { validateSettings } from "@/lib/validation";
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
  type Settings,
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
  return plain(res);
}

export async function setDriverStatus(driverId: string, status: DriverStatus): Promise<ActionResult> {
  if (!DRIVER_STATUSES.includes(status)) return { ok: false, error: "Unknown status" };
  const label = { APPROVED: "Driver approved", ON_HOLD: "Driver put on hold", REJECTED: "Driver rejected", PENDING: "Driver moved to pending" }[status];
  return plain(await run(() => adminApi.setDriverStatus(driverId, status), label, [`/drivers/${driverId}`, "/drivers", "/"]));
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
    [`/drivers/${driverId}`, "/drivers", "/kyc", "/"],
  ));
}

export async function updatePlan(planId: string, data: { price?: number; isActive?: boolean }): Promise<ActionResult> {
  if (data.price !== undefined && (!Number.isInteger(data.price) || data.price < 0 || data.price > 100_000)) {
    return { ok: false, error: "Price must be a whole number between ₹0 and ₹1,00,000" };
  }
  const message = data.price !== undefined ? "Price updated" : data.isActive ? "Plan activated" : "Plan deactivated";
  return plain(await run(() => adminApi.updatePlan(planId, data), message, ["/plans"]));
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

export async function saveSettings(input: Settings): Promise<ActionResult> {
  const errors = validateSettings(input);
  const first = Object.values(errors)[0];
  if (first) return { ok: false, error: first };
  const res = await run(() => adminApi.updateSettings(input), "Settings saved", ["/settings"]);
  return plain(res);
}
