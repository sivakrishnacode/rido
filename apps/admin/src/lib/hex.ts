import { cellToBoundary, cellToLatLng, getResolution, gridDisk, isValidCell, latLngToCell, polygonToCells } from "h3-js";

/** Average hexagon edge length by H3 resolution (km), same table as apps/api/src/modules/geo/h3.util.ts. */
const EDGE_KM = [1281.256, 483.057, 182.513, 68.979, 26.072, 9.854, 3.725, 1.406, 0.531, 0.201, 0.076, 0.029];

export const MAX_VIEWPORT_CELLS = 5_000;

/** Hexagon corners as [lat, lng] pairs (Leaflet order). */
export function hexBoundary(cell: string): [number, number][] {
  return cellToBoundary(cell) as [number, number][];
}

export function cellAt(lat: number, lng: number, resolution: number): string {
  return latLngToCell(lat, lng, resolution);
}

/** Cells covering a circle: the same k-ring maths the API uses to bootstrap a city. */
export function circleCells(lat: number, lng: number, radiusKm: number, resolution: number): string[] {
  const centre = latLngToCell(lat, lng, resolution);
  const edgeKm = EDGE_KM[resolution] ?? 0.531;
  const k = Math.max(0, Math.ceil(radiusKm / (edgeKm * Math.sqrt(3))));
  return gridDisk(centre, k);
}

/** Valid cells at [resolution]. */
export function isCellAt(cell: string, resolution: number): boolean {
  return isValidCell(cell) && getResolution(cell) === resolution;
}

/**
 * Cells inside a lat/lng box (the map viewport), or null when there would be too many to draw
 * (zoomed out too far). Estimated from the box area first so we never enumerate millions of cells.
 */
export function viewportCells(
  box: { south: number; west: number; north: number; east: number },
  resolution: number,
  max = MAX_VIEWPORT_CELLS,
): string[] | null {
  const kmPerDegLat = 111.32;
  const midLat = ((box.north + box.south) / 2) * (Math.PI / 180);
  const areaKm2 = (box.north - box.south) * kmPerDegLat * (box.east - box.west) * kmPerDegLat * Math.cos(midLat);
  const edge = EDGE_KM[resolution] ?? 0.531;
  const cellKm2 = ((3 * Math.sqrt(3)) / 2) * edge * edge;
  if (areaKm2 / cellKm2 > max) return null;
  const ring: [number, number][] = [
    [box.south, box.west],
    [box.south, box.east],
    [box.north, box.east],
    [box.north, box.west],
    [box.south, box.west],
  ];
  const cells = polygonToCells(ring, resolution);
  return cells.length > max ? null : cells;
}

/** Undo/redo history of cell sets (immutable snapshots). */
export interface CellHistory {
  readonly past: readonly string[][];
  readonly present: readonly string[];
  readonly future: readonly string[][];
}

export function historyInit(cells: readonly string[]): CellHistory {
  return { past: [], present: [...cells], future: [] };
}

/** Records a new state (no-op when nothing changed). Keeps the last 50 steps. */
export function historyPush(h: CellHistory, next: readonly string[]): CellHistory {
  if (next.length === h.present.length && next.every((c, i) => c === h.present[i])) return h;
  return { past: [...h.past, [...h.present]].slice(-50), present: [...next], future: [] };
}

export function historyUndo(h: CellHistory): CellHistory {
  if (h.past.length === 0) return h;
  const prev = h.past[h.past.length - 1];
  return { past: h.past.slice(0, -1), present: prev, future: [[...h.present], ...h.future] };
}

export function historyRedo(h: CellHistory): CellHistory {
  if (h.future.length === 0) return h;
  const [next, ...rest] = h.future;
  return { past: [...h.past, [...h.present]], present: next, future: rest };
}

/** Adds or removes cells, returning a sorted, de-duplicated list (stable for diffing and saving). */
export function applyCells(current: readonly string[], cells: readonly string[], mode: "add" | "remove"): string[] {
  const set = new Set(current);
  for (const c of cells) {
    if (mode === "add") set.add(c);
    else set.delete(c);
  }
  return [...set].sort();
}

/** Brush sizes: k-rings of 0–3 → 1, 7, 19, 37 hexagons. */
export const BRUSH_SIZES = [
  { k: 0, cells: 1 },
  { k: 1, cells: 7 },
  { k: 2, cells: 19 },
  { k: 3, cells: 37 },
] as const;

/** Cells under a brush of ring size [k] centred on [cell]. */
export function brushCells(cell: string, k: number): string[] {
  return k <= 0 ? [cell] : gridDisk(cell, k);
}

/**
 * Cells whose centres fall inside a drawn polygon ([lat, lng] vertices). Very small polygons that contain no centre
 * still give the cells under their vertices, so a quick three-click shape is never a no-op.
 */
export function polygonCells(points: readonly [number, number][], resolution: number): string[] {
  if (points.length < 3) return [];
  const ring = [...points, points[0]].map(([lat, lng]) => [lat, lng]);
  const inside = polygonToCells(ring, resolution);
  if (inside.length > 0) return inside;
  return [...new Set(points.map(([lat, lng]) => latLngToCell(lat, lng, resolution)))];
}

/** Bounding box of cell centres (null for an empty list). */
export function cellsBounds(cells: readonly string[]): { south: number; west: number; north: number; east: number } | null {
  if (cells.length === 0) return null;
  let south = 90;
  let north = -90;
  let west = 180;
  let east = -180;
  for (const c of cells) {
    const [lat, lng] = cellToLatLng(c);
    south = Math.min(south, lat);
    north = Math.max(north, lat);
    west = Math.min(west, lng);
    east = Math.max(east, lng);
  }
  return { south, west, north, east };
}

/** Rough centre of a set of cells (average of cell centres), for labels. */
export function cellsCentre(cells: readonly string[]): { lat: number; lng: number } | null {
  if (cells.length === 0) return null;
  let lat = 0;
  let lng = 0;
  for (const c of cells) {
    const [a, b] = cellToLatLng(c);
    lat += a;
    lng += b;
  }
  return { lat: lat / cells.length, lng: lng / cells.length };
}
