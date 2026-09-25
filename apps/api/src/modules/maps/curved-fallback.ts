import type { LatLngLiteral } from './polyline.js';

/** Gently curved stand-in line (quadratic Bézier) when no road route is available. */
export function curvedFallback(from: LatLngLiteral, to: LatLngLiteral, segments = 32): LatLngLiteral[] {
  const ctrl = {
    lat: (from.lat + to.lat) / 2 - (to.lng - from.lng) * 0.18,
    lng: (from.lng + to.lng) / 2 + (to.lat - from.lat) * 0.18,
  };
  return Array.from({ length: segments + 1 }, (_, i) => {
    const t = i / segments;
    const a = (1 - t) ** 2;
    const b = 2 * (1 - t) * t;
    const c = t ** 2;
    return { lat: a * from.lat + b * ctrl.lat + c * to.lat, lng: a * from.lng + b * ctrl.lng + c * to.lng };
  });
}
