import { humanize } from "./format";
import { cellsCentre } from "./hex";
import type { Zone } from "./types";

/** Map label for a zone: short name, surge badge, full text on hover; placed at its largest cluster's centre. */
export function zoneLabel(z: Pick<Zone, "id" | "name" | "kind" | "cells" | "surgeMultiplier" | "color" | "isActive">) {
  const c = cellsCentre(z.cells);
  if (!c) return null;
  const name = z.name.replace(/^high demand:\s*/i, "").trim() || z.name;
  const isSurge = z.kind === "SURGE";
  return {
    id: z.id,
    ...c,
    text: name,
    badge: isSurge ? `${Number(z.surgeMultiplier.toFixed(2))}×` : undefined,
    title: `${z.name} · ${humanize(z.kind)}${isSurge ? ` ${z.surgeMultiplier.toFixed(2)}×` : ""}${z.isActive ? "" : " · paused"}`,
    color: z.kind === "NO_SERVICE" ? "#B91C1C" : z.color,
    priority: (z.isActive ? 100_000 : 0) + z.cells.length,
  };
}
