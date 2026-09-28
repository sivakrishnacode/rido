import { SETTING_DEFAULTS } from '../settings/settings.defaults.js';
import { noShowAt, pickupCapAt, pickupCheckAt, pickupProgressVerdict, pickupRecheckAt, stuckAt } from './trip-timeouts.js';

const s = { ...SETTING_DEFAULTS };
const MIN = 60_000;
const T = 1_000_000_000;

describe('trip timeouts', () => {
  it('checks pickup progress after max(3 min, 1.5 × ETA)', () => {
    expect(pickupCheckAt(T, 10, s)).toBe(T + 15 * MIN);
    expect(pickupCheckAt(T, 1, s)).toBe(T + 3 * MIN);
    expect(pickupCheckAt(T, null, s)).toBe(T + 3 * MIN);
    expect(pickupRecheckAt(T, s)).toBe(T + 2 * MIN);
  });

  it('allows a no-show cancel 5 min after arriving', () => {
    expect(noShowAt(T, s)).toBe(T + 5 * MIN);
  });

  it('flags a started trip after max(2 h, 4 × estimate)', () => {
    expect(stuckAt(T, 20, s)).toBe(T + 120 * MIN);
    expect(stuckAt(T, 45, s)).toBe(T + 180 * MIN);
    expect(pickupCapAt(T, s)).toBe(T + 60 * MIN);
  });

  it('nudges once, then reassigns a driver who has not got 150 m closer', () => {
    expect(pickupProgressVerdict({ atAcceptM: 2000, nowM: 1800, minProgressM: 150, strikes: 0 })).toBe('moving');
    expect(pickupProgressVerdict({ atAcceptM: 2000, nowM: 1900, minProgressM: 150, strikes: 0 })).toBe('strike');
    expect(pickupProgressVerdict({ atAcceptM: 2000, nowM: 2100, minProgressM: 150, strikes: 1 })).toBe('reassign');
  });

  it('counts a missing GPS fix as not moving, and any fix as moving without a baseline', () => {
    expect(pickupProgressVerdict({ atAcceptM: 2000, nowM: null, minProgressM: 150, strikes: 0 })).toBe('strike');
    expect(pickupProgressVerdict({ atAcceptM: null, nowM: 900, minProgressM: 150, strikes: 1 })).toBe('moving');
  });
});
