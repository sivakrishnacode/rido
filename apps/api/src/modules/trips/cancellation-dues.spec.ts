import type { CancelSignals } from './cancel-fault.js';
import { cancellationDueAmount, withCancellationFee } from './cancellation-dues.js';

const waited: CancelSignals = {
  by: 'PASSENGER',
  code: 'CHANGED_MIND',
  fromStatus: 'DRIVER_ARRIVED',
  hasDriver: true,
  isArrived: true,
  waitedSec: 240,
  sinceAcceptSec: 600,
  atAcceptM: 1200,
  nowM: 20,
  isMovingAway: false,
  noShowWaitMin: 5,
  freeWaitMin: 3,
};
const passengerFault = { fault: 'PASSENGER', rule: 'passenger_after_wait' } as const;

describe('cancellation dues', () => {
  it('is nothing while the fee is off (the default)', () => {
    expect(cancellationDueAmount({ enabled: false, fee: 10, verdict: passengerFault, signals: waited })).toBe(0);
  });

  it('charges the fee when the passenger was at fault after the driver arrived and waited the free minutes', () => {
    expect(cancellationDueAmount({ enabled: true, fee: 10, verdict: passengerFault, signals: waited })).toBe(10);
    // A no-show cancel by the driver is the passenger's fault after the wait too.
    const noShow = { ...waited, by: 'DRIVER', code: 'PASSENGER_NO_SHOW', waitedSec: 310 } as const;
    expect(cancellationDueAmount({ enabled: true, fee: 10, verdict: { fault: 'PASSENGER', rule: 'passenger_no_show' }, signals: noShow })).toBe(10);
  });

  it('never before the driver arrived, before the free minutes, or for another verdict', () => {
    const on = { enabled: true, fee: 10 };
    expect(cancellationDueAmount({ ...on, verdict: passengerFault, signals: { ...waited, isArrived: false, waitedSec: null } })).toBe(0);
    expect(cancellationDueAmount({ ...on, verdict: passengerFault, signals: { ...waited, waitedSec: 179 } })).toBe(0);
    expect(cancellationDueAmount({ ...on, verdict: { fault: 'SHARED', rule: 'passenger_on_arrival' }, signals: waited })).toBe(0);
    expect(cancellationDueAmount({ ...on, verdict: { fault: 'DRIVER', rule: 'driver_after_arrival' }, signals: waited })).toBe(0);
    expect(cancellationDueAmount({ enabled: true, fee: 0, verdict: passengerFault, signals: waited })).toBe(0);
  });

  it('adds the fee as its own fare line, once', () => {
    const fare = withCancellationFee({ subtotal: 35, peakCharge: 0, waitingCharge: 0, total: 35 }, 10);
    expect(fare).toMatchObject({ previousCancellationFee: 10, total: 45 });
    expect(withCancellationFee(fare, 20).total).toBe(55);
  });
});
