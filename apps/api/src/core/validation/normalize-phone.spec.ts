import { normalizePhone } from './normalize-phone.js';

describe('normalizePhone', () => {
  it('accepts spaces, dashes and an optional +91', () => {
    expect(normalizePhone('98430 12345')).toBe('+919843012345');
    expect(normalizePhone('+91-98430-12345')).toBe('+919843012345');
    expect(normalizePhone('9843012345')).toBe('+919843012345');
    expect(normalizePhone('+919843012345')).toBe('+919843012345');
  });

  it('leaves invalid input for the validator to reject', () => {
    expect(normalizePhone('12345')).toBe('12345');
    expect(normalizePhone(42)).toBe(42);
  });
});
