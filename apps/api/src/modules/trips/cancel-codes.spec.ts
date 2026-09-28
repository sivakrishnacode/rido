import { isDriverFault, resolveCancel } from './cancel-codes.js';

describe('cancel codes', () => {
  it('keeps a code the side may use, with the note', () => {
    expect(resolveCancel({ by: 'PASSENGER', code: 'WAIT_TOO_LONG', note: ' 10 min late ' })).toEqual({ code: 'WAIT_TOO_LONG', note: '10 min late' });
    expect(resolveCancel({ by: 'DRIVER', code: 'VEHICLE_ISSUE' })).toEqual({ code: 'VEHICLE_ISSUE', note: null });
  });

  it("turns a code the side may not use into OTHER (a passenger can't claim a no-show)", () => {
    expect(resolveCancel({ by: 'PASSENGER', code: 'PASSENGER_NO_SHOW' }).code).toBe('OTHER');
    expect(resolveCancel({ by: 'DRIVER', code: 'DRIVER_NOT_MOVING' }).code).toBe('OTHER');
  });

  it('maps an old client reason text to its code and keeps it as the note', () => {
    expect(resolveCancel({ by: 'DRIVER', reason: 'Rider is not a woman' })).toEqual({ code: 'BUTTERFLY_MISMATCH', note: 'Rider is not a woman' });
    expect(resolveCancel({ by: 'PASSENGER', reason: 'Changed my plan' }).code).toBe('CHANGED_MIND');
    expect(resolveCancel({ by: 'PASSENGER', reason: 'Something else' })).toEqual({ code: 'OTHER', note: 'Something else' });
    expect(resolveCancel({ by: 'PASSENGER' })).toEqual({ code: 'OTHER', note: null });
  });

  it('counts driver cancels against the driver, except a no-show and a Butterfly report', () => {
    expect(isDriverFault('DRIVER', 'TOO_FAR')).toBe(true);
    expect(isDriverFault('DRIVER', 'PASSENGER_NO_SHOW')).toBe(false);
    expect(isDriverFault('DRIVER', 'BUTTERFLY_MISMATCH')).toBe(false);
    expect(isDriverFault('SYSTEM', 'DRIVER_NOT_MOVING')).toBe(true);
    expect(isDriverFault('SYSTEM', 'NO_DRIVERS')).toBe(false);
    expect(isDriverFault('PASSENGER', 'DRIVER_TOO_FAR')).toBe(false);
  });
});
