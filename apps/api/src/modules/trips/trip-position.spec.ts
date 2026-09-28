import { UnprocessableEntityException } from '@nestjs/common';

import { checkNearStop, positionForCheck, SERVER_FIX_MAX_AGE_MS } from './trip-position.js';

const pickup = { lat: 11.0183, lng: 76.9725 };
/** ~1.1 km north of the pickup. */
const far = { lat: 11.0283, lng: 76.9725 };

describe('checkNearStop', () => {
  it('passes inside the radius and records the distance', () => {
    const r = checkNearStop({ stop: 'pickup', at: { lat: 11.0185, lng: 76.9726 }, target: pickup, radiusM: 250 });
    expect(r.farReason).toBeNull();
    expect(r.distanceM).toBeGreaterThan(0);
    expect(r.distanceM).toBeLessThan(50);
  });

  it('asks for a reason when too far, with the distance in the error', () => {
    try {
      checkNearStop({ stop: 'pickup', at: far, target: pickup, radiusM: 250 });
      throw new Error('expected TOO_FAR');
    } catch (e) {
      expect(e).toBeInstanceOf(UnprocessableEntityException);
      const body = (e as UnprocessableEntityException).getResponse() as { code: string; message: string; details: { distanceM: number } };
      expect(body.code).toBe('TOO_FAR');
      expect(body.details.distanceM).toBeGreaterThan(1000);
      expect(body.message).toBe("You're 1.1 km from the pickup point");
    }
  });

  it('lets the driver continue with a reason', () => {
    const r = checkNearStop({ stop: 'drop', at: far, target: pickup, radiusM: 400, farReason: ' Customer asked to stop here ' });
    expect(r.farReason).toBe('Customer asked to stop here');
    expect(r.distanceM).toBeGreaterThan(1000);
  });

  it('does not block when the position is unknown', () => {
    expect(checkNearStop({ stop: 'drop', at: null, target: pickup, radiusM: 400 })).toEqual({ distanceM: null, farReason: null });
  });
});

describe('positionForCheck', () => {
  const now = 1_000_000;
  const server = { ...far, at: now - 5_000 };

  it('trusts a fresh server fix over the coordinates the app sends', () => {
    expect(positionForCheck({ server, sent: pickup, now })).toEqual(far);
  });

  it('uses the sent coordinates when the server fix is stale or has no time', () => {
    expect(positionForCheck({ server: { ...far, at: now - SERVER_FIX_MAX_AGE_MS - 1 }, sent: pickup, now })).toEqual(pickup);
    expect(positionForCheck({ server: { ...far, at: null }, sent: pickup, now })).toEqual(pickup);
    expect(positionForCheck({ server: null, sent: pickup, now })).toEqual(pickup);
  });

  it('falls back to a stale server fix, else unknown', () => {
    expect(positionForCheck({ server: { ...far, at: now - 60_000 }, sent: {}, now })).toEqual(far);
    expect(positionForCheck({ server: null, sent: { lat: 11 }, now })).toBeNull();
  });
});
