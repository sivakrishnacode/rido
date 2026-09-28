import { isShareLive, SHARE_AFTER_END_MS, SHARE_MAX_MS, shareExpiry, signShareToken, verifyShareToken } from './share-token.js';

const SECRET = 'test-secret-that-is-long-enough-32ch';
const NOW = Date.UTC(2026, 8, 28, 16, 0);
const TRIP = 'cmg1abcdefghijklmnop';

describe('share tokens', () => {
  it('verifies a token it signed and returns its claims', () => {
    const token = signShareToken({ tripId: TRIP, exp: NOW + 60_000 }, SECRET);
    expect(token.split('.')).toHaveLength(3);
    expect(verifyShareToken(token, SECRET, NOW)).toEqual({ tripId: TRIP, exp: NOW + 60_000 });
  });

  it('refuses an expired token', () => {
    const token = signShareToken({ tripId: TRIP, exp: NOW + 60_000 }, SECRET);
    expect(verifyShareToken(token, SECRET, NOW + 60_000)).toBeNull();
    expect(verifyShareToken(token, SECRET, NOW + 59_999)).not.toBeNull();
  });

  it('refuses tampered tokens and other secrets', () => {
    const token = signShareToken({ tripId: TRIP, exp: NOW + 60_000 }, SECRET);
    const [id, exp, sig] = token.split('.');
    // Arrange: a later expiry or another trip with the same signature.
    expect(verifyShareToken(`${id}.${(NOW + 9e9).toString(36)}.${sig}`, SECRET, NOW)).toBeNull();
    expect(verifyShareToken(`cmg1otherotherotherxx.${exp}.${sig}`, SECRET, NOW)).toBeNull();
    expect(verifyShareToken(token, 'another-secret-another-secret-xx', NOW)).toBeNull();
    expect(verifyShareToken(`${token}x`, SECRET, NOW)).toBeNull();
    expect(verifyShareToken('garbage', SECRET, NOW)).toBeNull();
    expect(verifyShareToken('', SECRET, NOW)).toBeNull();
  });

  it('expires 30 min after the trip ends, or after 12 h for a running trip', () => {
    const ended = new Date(NOW);
    expect(shareExpiry(ended, NOW + 5_000)).toBe(NOW + SHARE_AFTER_END_MS);
    expect(shareExpiry(null, NOW)).toBe(NOW + SHARE_MAX_MS);
    expect(isShareLive(null, NOW)).toBe(true);
    expect(isShareLive(ended, NOW + SHARE_AFTER_END_MS - 1)).toBe(true);
    expect(isShareLive(ended, NOW + SHARE_AFTER_END_MS)).toBe(false);
  });
});
