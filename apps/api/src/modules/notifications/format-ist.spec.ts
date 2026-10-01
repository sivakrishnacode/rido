import { formatIstShort } from './notifier.service.js';

describe('formatIstShort', () => {
  it('shows a scheduled pickup as weekday and time in IST', () => {
    expect(formatIstShort(new Date('2026-10-06T00:30:00Z'))).toBe('Tue 6:00 am');
    expect(formatIstShort(new Date('2026-10-07T14:45:00Z'))).toBe('Wed 8:15 pm');
  });
});
