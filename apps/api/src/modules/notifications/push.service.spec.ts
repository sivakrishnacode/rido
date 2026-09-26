import { PushService } from './push.service.js';

describe('PushService.payload', () => {
  it('ride requests are urgent, on their channel, and expire with the offer', () => {
    const p = PushService.payload({
      title: 'New ride request · ₹49',
      body: 'Gandhipuram → Brookefields',
      channel: 'ride_requests',
      data: { type: 'offer', tripId: 't1' },
      isUrgent: true,
      ttlSeconds: 15,
    });
    expect(p.android?.priority).toBe('high');
    expect(p.android?.ttl).toBe(15_000);
    expect(p.android?.notification?.channelId).toBe('ride_requests');
    expect(p.android?.notification?.tag).toBe('trip-t1');
    expect(p.data).toEqual({ type: 'offer', tripId: 't1', channel: 'ride_requests' });
  });

  it('other messages are normal priority without a TTL', () => {
    const p = PushService.payload({ title: 'Hi', body: 'x', channel: 'announcements' });
    expect(p.android?.priority).toBe('normal');
    expect(p.android?.ttl).toBeUndefined();
    expect(p.data).toEqual({ channel: 'announcements' });
  });
});
