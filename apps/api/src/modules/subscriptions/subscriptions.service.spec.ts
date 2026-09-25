import type { Subscription } from '../../generated/prisma/client.js';
import { SubscriptionsService } from './subscriptions.service.js';

const base = { status: 'ACTIVE', endsAt: new Date('2026-10-24T00:00:00Z') } as Subscription;

describe('SubscriptionsService.effectiveStatus', () => {
  it('stays active before the end date', () => {
    expect(SubscriptionsService.effectiveStatus(base, new Date('2026-10-20T00:00:00Z'))).toBe('ACTIVE');
  });

  it('moves to grace for 2 days after the end date', () => {
    expect(SubscriptionsService.effectiveStatus(base, new Date('2026-10-25T12:00:00Z'))).toBe('GRACE');
  });

  it('expires after the grace period', () => {
    expect(SubscriptionsService.effectiveStatus(base, new Date('2026-10-27T00:00:00Z'))).toBe('EXPIRED');
  });

  it('keeps paused and cancelled as they are', () => {
    const paused = { ...base, status: 'PAUSED' } as Subscription;
    expect(SubscriptionsService.effectiveStatus(paused, new Date('2026-11-30T00:00:00Z'))).toBe('PAUSED');
  });
});
