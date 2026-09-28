import { SETTING_DEFAULTS } from '../settings/settings.defaults.js';
import { blockHours, CANCEL_RATE_WINDOW_MS, cancelRateLevel, cancelRateMessage, cancelRateSince, passengerCancelRate } from './cancel-rate.js';

const s = SETTING_DEFAULTS;

describe('driver cancellation rate', () => {
  it('needs the minimum number of assigned trips before judging', () => {
    expect(cancelRateLevel({ cancelled: 4, assigned: 4 }, s)).toEqual({ rate: 1, level: 'OK' });
    expect(cancelRateLevel({ cancelled: 0, assigned: 0 }, s)).toEqual({ rate: 0, level: 'OK' });
  });

  it('nudges from 30 % and pauses from 50 %', () => {
    expect(cancelRateLevel({ cancelled: 1, assigned: 5 }, s).level).toBe('OK');
    expect(cancelRateLevel({ cancelled: 2, assigned: 6 }, s)).toEqual({ rate: 0.333, level: 'NUDGE' });
    expect(cancelRateLevel({ cancelled: 3, assigned: 6 }, s)).toEqual({ rate: 0.5, level: 'BLOCK' });
    expect(cancelRateLevel({ cancelled: 5, assigned: 5 }, s).level).toBe('BLOCK');
  });

  it('follows the settings', () => {
    const strict = { cancelRateMinTrips: 2, cancelRateNudge: 0.1, cancelRateBlock: 0.2 };
    expect(cancelRateLevel({ cancelled: 1, assigned: 3 }, strict).level).toBe('BLOCK');
    expect(cancelRateLevel({ cancelled: 1, assigned: 1 }, strict).level).toBe('OK');
  });

  it('counts the last 7 days, restarting after the last pause', () => {
    const now = Date.UTC(2026, 8, 28, 12);
    expect(cancelRateSince(now, null).getTime()).toBe(now - CANCEL_RATE_WINDOW_MS);
    const ended = new Date(now - 86_400_000);
    expect(cancelRateSince(now, ended)).toEqual(ended);
    // A pause that is still running (ends later) doesn't move the window.
    expect(cancelRateSince(now, new Date(now + 3_600_000)).getTime()).toBe(now - CANCEL_RATE_WINDOW_MS);
  });

  it('pauses longer when there was another pause this week', () => {
    expect(blockHours(false, s)).toBe(24);
    expect(blockHours(true, s)).toBe(72);
  });

  it('computes a passenger\'s rates for admins (never blocks them)', () => {
    const since = new Date('2026-08-29T00:00:00Z');
    expect(passengerCancelRate({ since, booked: 8, cancelled: 4, atFault: 1 })).toMatchObject({ rate: 0.5, faultRate: 0.125 });
    expect(passengerCancelRate({ since, booked: 0, cancelled: 0, atFault: 0 })).toMatchObject({ rate: 0, faultRate: 0 });
  });

  it('tells the driver how many rides they cancelled', () => {
    expect(cancelRateMessage({ cancelled: 2, assigned: 5, level: 'NUDGE' }, s)).toEqual({
      title: "You've cancelled 2 of your last 5 rides",
      body: "If you cancel 50% of your rides, you can't go online for 24 h. Only accept rides you can reach",
    });
    expect(cancelRateMessage({ cancelled: 3, assigned: 5, level: 'BLOCK' }, s).title).toBe('Account paused');
  });
});
