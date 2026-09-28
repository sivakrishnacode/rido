// Safety records from the API (apps/api/src/modules/safety): SOS alerts and trip safety events, and how the admin
// panel words them. Pure (unit-tested).
export type SosStatus = "OPEN" | "ACKNOWLEDGED" | "RESOLVED" | "FALSE_ALARM";
export const SOS_STATUSES: readonly SosStatus[] = ["OPEN", "ACKNOWLEDGED", "RESOLVED", "FALSE_ALARM"];
export type SosSource = "BUTTON" | "CHECK" | "ARRIVAL";
export type SafetyEventKind = "STOP" | "DEVIATION" | "NIGHT_CHECK" | "SOS_LINKED";

/** An SOS row (GET /admin/trips/:id `sos`). */
export interface SosRecord {
  readonly id: string;
  readonly tripId: string;
  readonly userId: string;
  readonly role: "PASSENGER" | "DRIVER";
  readonly lat: number | null;
  readonly lng: number | null;
  readonly status: SosStatus;
  readonly source: SosSource | string;
  readonly note: string | null;
  readonly acknowledgedAt: string | null;
  readonly acknowledgedBy: string | null;
  readonly resolvedAt: string | null;
  readonly resolvedBy: string | null;
  readonly createdAt: string;
}

type Person = { readonly name: string | null; readonly phone: string };

/** GET /admin/sos item. */
export interface SosListItem extends SosRecord {
  readonly user: Person & { readonly id: string };
  readonly trip: {
    readonly id: string;
    readonly status: string;
    readonly kind: "RIDE" | "PARCEL";
    readonly pickupName: string;
    readonly dropName: string;
    readonly passenger: Person;
    readonly driver: { readonly id: string; readonly plate: string; readonly user: Person } | null;
  };
}

/** GET /admin/sos: a page plus the open count (sidebar badge). */
export interface SosPage {
  readonly items: SosListItem[];
  readonly total: number;
  readonly page: number;
  readonly pageSize: number;
  readonly open: number;
}

/** A trip safety event (GET /admin/trips/:id `safetyEvents`). */
export interface SafetyEvent {
  readonly id: string;
  readonly tripId: string;
  readonly kind: SafetyEventKind;
  readonly payload: Record<string, unknown> | null;
  readonly at: string;
}

/** How often the SOS page reloads itself. */
export const SOS_REFRESH_MS = 10_000;

/** "Pressed SOS" / "Asked for help (safety check)" / "Didn't reach safely". */
export function sosSourceLabel(source: string): string {
  if (source === "CHECK") return "Asked for help (safety check)";
  if (source === "ARRIVAL") return "Didn't reach safely";
  return "Pressed SOS";
}

/** A Google Maps link to where the SOS was raised, or null. */
export function sosMapUrl(s: { lat: number | null; lng: number | null }): string | null {
  return s.lat === null || s.lng === null ? null : `https://maps.google.com/?q=${s.lat.toFixed(5)},${s.lng.toFixed(5)}`;
}

/** Still needs someone (open or acknowledged). */
export function isSosActive(status: SosStatus): boolean {
  return status === "OPEN" || status === "ACKNOWLEDGED";
}

const num = (v: unknown): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);

/** One line for a safety event on the trip page. */
export function safetyEventLine(e: Pick<SafetyEvent, "kind" | "payload">): { title: string; detail: string } {
  const p = e.payload ?? {};
  switch (e.kind) {
    case "SOS_LINKED":
      return { title: "SOS", detail: `${p.role === "DRIVER" ? "Driver" : "Passenger"} · ${sosSourceLabel(String(p.source ?? "BUTTON"))}` };
    case "STOP": {
      const min = num(p.minutes);
      const answer = p.answer === "OK" ? " · rider said OK" : p.answer === "HELP" ? " · rider asked for help" : "";
      return { title: "Long stop", detail: `Stopped ${min !== null ? `${min} min` : ""} away from pickup and drop${p.pushed ? " · rider asked \"Is everything OK?\"" : ""}${answer}`.replace(/\s+/g, " ").trim() };
    }
    case "DEVIATION": {
      const off = num(p.offM);
      const answer = p.answer === "OK" ? " · rider said OK" : p.answer === "HELP" ? " · rider asked for help" : "";
      return { title: "Off route", detail: `${off !== null ? `${off} m` : "Far"} from the quoted route${p.night ? " at night" : ""}${p.pushed ? " · rider asked \"Is everything OK?\"" : ""}${answer}` };
    }
    case "NIGHT_CHECK": {
      const answer = p.answer === "OK" ? " · rider said OK" : p.answer === "HELP" ? " · rider asked for help" : "";
      const what = p.check === "SAFE_ARRIVAL" ? "\"Did you reach safely?\" sent" : "Night ride: \"Share your trip\" reminder sent";
      return { title: "Night check", detail: `${what}${answer}` };
    }
    default:
      return { title: String(e.kind), detail: "" };
  }
}
