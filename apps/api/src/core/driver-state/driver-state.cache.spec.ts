import { decodeDriverState } from './driver-state.cache.js';

describe('decodeDriverState', () => {
  it('reads the cached online flag, vehicle and block flag', () => {
    expect(decodeDriverState('1|BIKE|0')).toEqual({ isOnline: true, vehicleKind: 'BIKE', isBlocked: false });
    expect(decodeDriverState('0|CAB|1')).toEqual({ isOnline: false, vehicleKind: 'CAB', isBlocked: true });
  });

  it('treats anything else as a miss', () => {
    for (const raw of ['', 'x', '2|BIKE|0', '1||0']) expect(decodeDriverState(raw)).toBeNull();
  });
});
