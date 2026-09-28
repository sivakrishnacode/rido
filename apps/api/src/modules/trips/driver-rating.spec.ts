import { averageRating } from './driver-rating.js';

describe('averageRating', () => {
  it('averages only rated rides', () => {
    // 3 ratings (5, 4, 3) over, say, 10 rides: the average is 4, not diluted by the 7 unrated ones.
    expect(averageRating({ sum: 12, count: 3 })).toBe(4);
  });

  it('rounds to 2 decimals', () => {
    expect(averageRating({ sum: 14, count: 3 })).toBe(4.67);
  });

  it('keeps the starting rating until the first one', () => {
    expect(averageRating({ sum: 0, count: 0 })).toBe(5);
    expect(averageRating({ sum: 0, count: 0, fallback: 4.8 })).toBe(4.8);
  });
});
