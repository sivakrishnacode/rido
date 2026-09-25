import { canTransition, isFinished } from './trip-transitions.js';

describe('trip transitions', () => {
  it('lets a ride go through its lifecycle', () => {
    const steps = ['SEARCHING', 'DRIVER_ASSIGNED', 'DRIVER_ARRIVED', 'IN_PROGRESS', 'COMPLETED'] as const;
    for (let i = 0; i < steps.length - 1; i++) {
      expect(canTransition({ kind: 'RIDE', from: steps[i], to: steps[i + 1] })).toBe(true);
    }
  });

  it('lets a parcel go through pickup and delivery', () => {
    expect(canTransition({ kind: 'PARCEL', from: 'DRIVER_ARRIVED', to: 'PICKED_UP' })).toBe(true);
    expect(canTransition({ kind: 'PARCEL', from: 'PICKED_UP', to: 'DELIVERED' })).toBe(true);
  });

  it('rejects skipping steps and changing finished trips', () => {
    expect(canTransition({ kind: 'RIDE', from: 'SEARCHING', to: 'IN_PROGRESS' })).toBe(false);
    expect(canTransition({ kind: 'RIDE', from: 'IN_PROGRESS', to: 'CANCELLED' })).toBe(false);
    expect(canTransition({ kind: 'RIDE', from: 'COMPLETED', to: 'CANCELLED' })).toBe(false);
    expect(isFinished('DELIVERED')).toBe(true);
  });
});
