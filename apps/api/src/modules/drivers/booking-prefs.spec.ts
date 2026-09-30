import { fitsPrefs, MAX_AREAS, readPrefs } from './booking-prefs.js';

const now = new Date('2026-09-29T10:00:00Z');
// Gandhipuram → the pickup is ~1.4 km away.
const driver = { lat: 11.0168, lng: 76.9558, distanceKm: 1.4 };
// Pickup at Gandhipuram bus stand, drop in Ukkadam.
const trip = { distanceKm: 6.2, pickupLat: 11.0183, pickupLng: 76.9725, dropLat: 10.9925, dropLng: 76.9614 };

describe('fitsPrefs', () => {
  it('no preferences: every trip fits', () => {
    expect(fitsPrefs({}, driver, trip)).toBe(true);
  });

  it('pickup farther than the maximum is left out', () => {
    expect(fitsPrefs({ maxPickupKm: 2 }, driver, trip)).toBe(true);
    expect(fitsPrefs({ maxPickupKm: 1 }, driver, trip)).toBe(false);
  });

  it('trip length outside the range is left out', () => {
    expect(fitsPrefs({ minTripKm: 5 }, driver, trip)).toBe(true);
    expect(fitsPrefs({ minTripKm: 8 }, driver, trip)).toBe(false);
    expect(fitsPrefs({ maxTripKm: 5 }, driver, trip)).toBe(false);
    expect(fitsPrefs({ minTripKm: 5, maxTripKm: 10 }, driver, trip)).toBe(true);
  });

  it('go-to: only trips that end near home or take the driver at least halfway there', () => {
    const until = '2026-09-29T12:00:00Z';
    // Home in Ukkadam: the trip ends there.
    expect(fitsPrefs({ goTo: { lat: 10.99, lng: 76.96, name: 'Home', until } }, driver, trip)).toBe(true);
    // Home in Saravanampatti (north, ~12 km): a trip south to Ukkadam goes the wrong way.
    expect(fitsPrefs({ goTo: { lat: 11.0797, lng: 76.9997, name: 'Home', until } }, driver, trip)).toBe(false);
  });

  it('stay-in: only trips that start and end inside the area', () => {
    const until = '2026-09-29T22:00:00Z';
    // Town Hall: Gandhipuram (~3 km) and Ukkadam (~0.2 km) are both within 5 km; the pickup is not within 2 km.
    const townHall = { lat: 10.9941, lng: 76.9612, name: 'Town Hall', until };
    expect(fitsPrefs({ stayIn: { ...townHall, radiusKm: 5 } }, driver, trip)).toBe(true);
    expect(fitsPrefs({ stayIn: { ...townHall, radiusKm: 2 } }, driver, trip)).toBe(false);
    // Saravanampatti, 5 km around it: the trip starts and ends outside.
    expect(fitsPrefs({ stayIn: { lat: 11.0797, lng: 76.9997, name: 'Saravanampatti', radiusKm: 5, until } }, driver, trip)).toBe(false);
  });
});

describe('readPrefs', () => {
  it('drops malformed values and an expired go-to', () => {
    expect(readPrefs(null, now)).toEqual({});
    expect(readPrefs({ maxPickupKm: -1, minTripKm: 'x', maxTripKm: 12 }, now)).toEqual({
      maxPickupKm: null,
      minTripKm: null,
      maxTripKm: 12,
      goTo: null,
      stayIn: null,
      parcels: true,
      areas: [],
    });
    const goTo = { lat: 11, lng: 77, name: 'Home', until: '2026-09-29T09:00:00Z' };
    expect(readPrefs({ goTo }, now).goTo).toBeNull();
    expect(readPrefs({ goTo: { ...goTo, until: '2026-09-29T11:00:00Z' } }, now).goTo?.name).toBe('Home');
  });

  it('reads stay-in, parcels and saved areas', () => {
    const stayIn = { lat: 11, lng: 77, name: 'RS Puram', radiusKm: 5, until: '2026-09-29T20:00:00Z' };
    expect(readPrefs({ stayIn }, now).stayIn).toEqual(stayIn);
    expect(readPrefs({ stayIn: { ...stayIn, until: '2026-09-29T09:00:00Z' } }, now).stayIn).toBeNull();
    expect(readPrefs({ stayIn: { ...stayIn, radiusKm: 0 } }, now).stayIn).toBeNull();
    expect(readPrefs({ parcels: false }, now).parcels).toBe(false);
    const areas = [{ name: 'Home', lat: 11.08, lng: 77 }, { name: 'Broken' }, ...Array.from({ length: 8 }, (_, i) => ({ name: `A${i}`, lat: 11, lng: 77 }))];
    const read = readPrefs({ areas }, now).areas!;
    expect(read).toHaveLength(MAX_AREAS);
    expect(read[0]).toEqual({ name: 'Home', lat: 11.08, lng: 77 });
    expect(read.map((a) => a.name)).not.toContain('Broken');
  });
});
