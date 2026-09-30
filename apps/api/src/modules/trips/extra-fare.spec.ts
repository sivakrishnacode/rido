import { extraOf, extraProblem, maxExtra, withExtra } from './extra-fare.js';

describe('extra fare', () => {
  it('lets the rider add up to half the quote, at least ₹100', () => {
    expect(maxExtra(35)).toBe(100);
    expect(maxExtra(420)).toBe(210);
    expect(maxExtra(923)).toBe(460);
  });

  it('only more than before, in whole rupees, within the cap', () => {
    expect(extraProblem({ amount: 20, was: 0, quoteTotal: 50 })).toBeNull();
    expect(extraProblem({ amount: 20, was: 20, quoteTotal: 50 })).toBe('You already added ₹20');
    expect(extraProblem({ amount: 10, was: 20, quoteTotal: 50 })).toBe('You already added ₹20');
    expect(extraProblem({ amount: 110, was: 0, quoteTotal: 50 })).toBe('You can add up to ₹100');
    expect(extraProblem({ amount: 12.5, was: 0, quoteTotal: 50 })).toBe('Add a whole number of rupees');
  });

  it('replaces the extra line and moves the total by the difference', () => {
    const once = withExtra({ total: 50 }, 10);
    expect(once).toEqual({ total: 60, extra: 10 });
    expect(withExtra(once, 30)).toEqual({ total: 80, extra: 30 });
    expect(extraOf(withExtra(once, 30))).toBe(30);
    expect(extraOf({ total: 50 })).toBe(0);
    expect(extraOf(null)).toBe(0);
  });
});
