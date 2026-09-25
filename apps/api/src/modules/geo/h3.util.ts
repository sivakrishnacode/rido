import { cellToBoundary, getResolution, gridDisk, isValidCell, latLngToCell } from 'h3-js';

/** Recommended resolution: 8 ≈ 0.74 km² per hexagon (~460 m edge). */
export const DEFAULT_H3_RESOLUTION = 8;

/** Cells covering a circle (used to bootstrap a new city's service area). */
export function cellsForCircle(params: { lat: number; lng: number; radiusKm: number; resolution: number }): string[] {
  const centre = latLngToCell(params.lat, params.lng, params.resolution);
  // Centre-to-centre spacing ≈ √3 × edge; average edge length by resolution (km).
  const edgeKm = [1281.256, 483.057, 182.513, 68.979, 26.072, 9.854, 3.725, 1.406, 0.531, 0.201, 0.076, 0.029][params.resolution] ?? 0.531;
  const k = Math.max(0, Math.ceil(params.radiusKm / (edgeKm * Math.sqrt(3))));
  return gridDisk(centre, k);
}

/** Keeps only valid cells at [resolution]; returns the rejected ones too. */
export function validateCells(cells: readonly string[], resolution: number): { valid: string[]; invalid: string[] } {
  const valid: string[] = [];
  const invalid: string[] = [];
  for (const c of new Set(cells)) {
    if (isValidCell(c) && getResolution(c) === resolution) valid.push(c);
    else invalid.push(c);
  }
  return { valid, invalid };
}

/** Cell containing a point. */
export function cellAt(lat: number, lng: number, resolution: number): string {
  return latLngToCell(lat, lng, resolution);
}

/** Hexagon corners as [lat, lng] pairs. */
export function cellPolygon(cell: string): [number, number][] {
  return cellToBoundary(cell);
}
