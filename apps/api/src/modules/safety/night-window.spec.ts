import { isNightIst, istHourOf } from './night-window.js';

/** [h]:[m] IST on 28 Sep 2026 as a Date (IST = UTC + 5:30). */
const ist = (h: number, m = 0) => new Date(Date.UTC(2026, 8, 28, h, m) - 330 * 60_000);

describe('night window (IST)', () => {
  it('converts UTC to the IST hour', () => {
    expect(istHourOf(new Date(Date.UTC(2026, 8, 28, 16, 29)))).toBe(21); // 21:59 IST
    expect(istHourOf(new Date(Date.UTC(2026, 8, 28, 16, 30)))).toBe(22);
    expect(istHourOf(new Date(Date.UTC(2026, 8, 28, 23, 30)))).toBe(5); // 05:00 next day
  });

  it('22:00–05:00 wraps past midnight', () => {
    expect(isNightIst(ist(21, 59), 22, 5)).toBe(false);
    expect(isNightIst(ist(22, 0), 22, 5)).toBe(true);
    expect(isNightIst(ist(0, 30), 22, 5)).toBe(true);
    expect(isNightIst(ist(4, 59), 22, 5)).toBe(true);
    expect(isNightIst(ist(5, 0), 22, 5)).toBe(false);
    expect(isNightIst(ist(13, 0), 22, 5)).toBe(false);
  });

  it('a window within one day, and an empty one', () => {
    expect(isNightIst(ist(1), 0, 4)).toBe(true);
    expect(isNightIst(ist(4), 0, 4)).toBe(false);
    expect(isNightIst(ist(22), 22, 22)).toBe(false);
  });
});
