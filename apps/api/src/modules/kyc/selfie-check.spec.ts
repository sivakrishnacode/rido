import { isSelfieCheckRequired, selfieTriesKey } from './selfie-check.js';

const base = { isEnabled: true, isDiditEnabled: true, hasReferenceFace: true, checkedAt: null, now: new Date('2026-10-02T04:30:00Z') };

describe('daily selfie check', () => {
  it('asks once per IST day', () => {
    expect(isSelfieCheckRequired(base)).toBe(true);
    // 09:00 IST today: done for the day.
    expect(isSelfieCheckRequired({ ...base, checkedAt: new Date('2026-10-02T03:30:00Z') })).toBe(false);
    // 23:00 IST yesterday (17:30 UTC) is a different IST day, though the same UTC day as 00:30 IST today.
    expect(isSelfieCheckRequired({ ...base, checkedAt: new Date('2026-10-01T17:30:00Z'), now: new Date('2026-10-01T19:00:00Z') })).toBe(true);
    expect(isSelfieCheckRequired({ ...base, checkedAt: new Date('2026-10-01T18:40:00Z'), now: new Date('2026-10-01T19:00:00Z') })).toBe(false);
  });

  it('never asks when switched off, without Didit or without a reference face', () => {
    expect(isSelfieCheckRequired({ ...base, isEnabled: false })).toBe(false);
    expect(isSelfieCheckRequired({ ...base, isDiditEnabled: false })).toBe(false);
    expect(isSelfieCheckRequired({ ...base, hasReferenceFace: false })).toBe(false);
  });

  it('counts tries per IST day', () => {
    expect(selfieTriesKey('d1', new Date('2026-10-01T19:00:00Z'))).toBe('driver:selfie-tries:d1:2026-10-02');
  });
});
