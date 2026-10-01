import { displayName, formatInr, formatPhone, humanize, shortId, vehicleLabel } from "./format";
import { withQuery } from "./paging";
import type { SearchResults } from "./types";

export type PaletteGroup = "Search" | "Pages" | "Drivers" | "Riders & accounts" | "Trips";

export interface PaletteItem {
  readonly id: string;
  readonly group: PaletteGroup;
  readonly label: string;
  readonly hint?: string;
  readonly href: string;
}

export interface PalettePage {
  readonly href: string;
  readonly label: string;
  readonly group: string;
  readonly searchHint?: string;
}

/**
 * What the Ctrl+K palette lists for [q]: "search this list for q" (the open list page, else All drivers), matching
 * pages (every page while q is empty), then drivers, people and trips from GET /admin/search.
 */
export function paletteItems(params: {
  q: string;
  current: PalettePage;
  fallbackSearch: PalettePage;
  pages: readonly PalettePage[];
  results: SearchResults | null;
}): PaletteItem[] {
  const q = params.q.trim();
  const needle = q.toLowerCase();
  const items: PaletteItem[] = [];
  if (q) {
    const target = params.current.searchHint ? params.current : params.fallbackSearch;
    items.push({ id: `search:${target.href}`, group: "Search", label: `Search ${target.label.toLowerCase()} for “${q}”`, href: withQuery(target.href, { q }) });
  }
  const pages = needle ? params.pages.filter((p) => `${p.label} ${p.group}`.toLowerCase().includes(needle)) : params.pages;
  for (const p of pages) items.push({ id: `page:${p.href}`, group: "Pages", label: p.label, hint: p.group, href: p.href });
  const r = params.results;
  if (r) {
    for (const d of r.drivers) {
      items.push({
        id: `driver:${d.id}`,
        group: "Drivers",
        label: displayName(d.user),
        hint: `${d.plate} · ${vehicleLabel(d.vehicleKind)} · ${humanize(d.status)}${d.isOnline ? " · online" : ""}`,
        href: `/drivers/${d.id}`,
      });
    }
    for (const u of r.people) {
      items.push({
        id: `user:${u.id}`,
        group: "Riders & accounts",
        label: displayName(u),
        hint: `${formatPhone(u.phone)} · ${u.role === "PASSENGER" ? "Rider" : humanize(u.role)}${u.isBlocked ? " · blocked" : ""}`,
        href: `/users/${u.id}`,
      });
    }
    for (const t of r.trips) {
      items.push({
        id: `trip:${t.id}`,
        group: "Trips",
        label: `#${shortId(t.id)} ${t.pickupName} → ${t.dropName}`,
        hint: `${humanize(t.status)} · ${formatInr(t.fareTotal)}`,
        href: `/trips/${t.id}`,
      });
    }
  }
  return items;
}
