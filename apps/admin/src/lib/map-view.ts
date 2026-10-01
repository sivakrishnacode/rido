/**
 * Map views. No city is built in: every city (and its centre) comes from the database, so a map without a city to
 * show starts on all of India.
 */
export const NO_CITY_VIEW = { center: { lat: 22.35, lng: 78.67 }, zoom: 5 } as const;

/** The first city's centre and a city zoom, or [NO_CITY_VIEW] when there is none. */
export function cityView(
  cities: readonly { centerLat: number; centerLng: number }[],
  zoom = 12,
): { center: { lat: number; lng: number }; zoom: number } {
  const c = cities[0];
  return c ? { center: { lat: c.centerLat, lng: c.centerLng }, zoom } : NO_CITY_VIEW;
}
