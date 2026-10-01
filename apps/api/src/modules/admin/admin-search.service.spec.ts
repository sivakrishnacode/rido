import { tripIdQuery } from './admin-search.service.js';

describe('tripIdQuery', () => {
  it('reads the short id the panel shows, or a full id', () => {
    expect(tripIdQuery('#E0TVH8TX')).toBe('e0tvh8tx');
    expect(tripIdQuery('cmg1abc2d0000xyz')).toBe('cmg1abc2d0000xyz');
    expect(tripIdQuery('Brookefields Mall')).toBeNull();
    expect(tripIdQuery('ab')).toBeNull();
  });
});
