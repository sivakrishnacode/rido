import { fareReviewNotes, mergeReviewNote } from './fare-review.js';

const clean = { actualDistanceM: 6100, gpsMockCount: 0, gpsPoints: 80, distanceCalcFailed: false };

describe('fareReviewNotes', () => {
  it('passes a normal trip', () => {
    expect(fareReviewNotes({ path: clean, quotedKm: 6, isPickupFar: false, isDropFar: false })).toEqual([]);
  });

  it('flags mock GPS fixes', () => {
    expect(fareReviewNotes({ path: { ...clean, gpsMockCount: 3 }, quotedKm: 6, isPickupFar: false, isDropFar: false })).toEqual([
      'Mock GPS: 3 fixes from a fake-location app',
    ]);
  });

  it('flags a distance that could not be measured', () => {
    const notes = fareReviewNotes({ path: { ...clean, actualDistanceM: null, gpsPoints: 1, distanceCalcFailed: true }, quotedKm: 6, isPickupFar: false, isDropFar: false });
    expect(notes).toEqual(['GPS distance not measured (1 point or a gap over 2 km)']);
  });

  it('flags a big distance difference only when a stop was outside its radius', () => {
    const far = { ...clean, actualDistanceM: 9000 };
    expect(fareReviewNotes({ path: far, quotedKm: 6, isPickupFar: false, isDropFar: false })).toEqual([]);
    expect(fareReviewNotes({ path: far, quotedKm: 6, isPickupFar: false, isDropFar: true })).toEqual([
      'Drove 9.0 km vs 6.0 km quoted, and ended away from the drop',
    ]);
  });

  it('uses max(1.2 km, 25 %) as the allowed difference', () => {
    const at = (actualDistanceM: number, quotedKm: number) =>
      fareReviewNotes({ path: { ...clean, actualDistanceM }, quotedKm, isPickupFar: true, isDropFar: false }).length;
    // Short trip: 1.2 km is the floor.
    expect(at(3100, 2)).toBe(0);
    expect(at(3300, 2)).toBe(1);
    // Long trip: 25 % of 20 km = 5 km.
    expect(at(24_500, 20)).toBe(0);
    expect(at(25_500, 20)).toBe(1);
    expect(at(14_500, 20)).toBe(1);
  });
});

describe('mergeReviewNote', () => {
  it('keeps an earlier note and adds the new ones', () => {
    expect(mergeReviewNote('Still running 130 min', ['Mock GPS: 1 fix'])).toBe('Still running 130 min; Mock GPS: 1 fix');
    expect(mergeReviewNote(null, [])).toBeNull();
  });
});
