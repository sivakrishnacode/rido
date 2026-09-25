import { istHour } from './hex-stats.service.js';

describe('istHour', () => {
  it('converts UTC to IST (+5:30)', () => {
    expect(istHour(new Date('2026-09-25T02:29:00Z'))).toBe(7);
    expect(istHour(new Date('2026-09-25T02:30:00Z'))).toBe(8);
    expect(istHour(new Date('2026-09-25T20:00:00Z'))).toBe(1);
  });
});
