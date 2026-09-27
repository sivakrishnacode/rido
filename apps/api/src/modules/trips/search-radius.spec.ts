import { searchRadiusAt, searchWindowMs } from './search-radius.js';

const s = { searchRadiusKm: 5, maxSearchRadiusKm: 15, searchExpandSeconds: 45 };

describe('searchRadiusAt', () => {
  it('starts at the start radius and widens linearly to the maximum', () => {
    expect(searchRadiusAt(0, s)).toBe(5);
    expect(searchRadiusAt(22_500, s)).toBe(10);
    expect(searchRadiusAt(45_000, s)).toBe(15);
    expect(searchRadiusAt(120_000, s)).toBe(15);
  });

  it('jumps to the maximum with no widening time, and never goes below the start radius', () => {
    expect(searchRadiusAt(0, { ...s, searchExpandSeconds: 0 })).toBe(15);
    expect(searchRadiusAt(60_000, { ...s, maxSearchRadiusKm: 3 })).toBe(5);
  });
});

describe('searchWindowMs', () => {
  it('lasts long enough for the radius to widen fully, and keeps the old minimums', () => {
    expect(searchWindowMs(false, s)).toBe(60_000);
    expect(searchWindowMs(true, s)).toBe(90_000);
    expect(searchWindowMs(false, { ...s, searchExpandSeconds: 0 })).toBe(30_000);
  });
});
