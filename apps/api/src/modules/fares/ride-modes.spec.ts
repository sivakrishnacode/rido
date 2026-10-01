import { VehicleKind } from '../../generated/prisma/enums.js';
import { istDays, modeQuote, outstationTerms, rentalTerms, settleMode, withSettlement } from './ride-modes.js';

describe('rentals', () => {
  it('prices a package per cab tier and settles extra km and minutes at the end', () => {
    const t = rentalTerms('CAB', '4h')!;
    expect(t).toMatchObject({ hours: 4, km: 40, price: 849, extraKmRate: 12, extraMinRate: 2 });
    expect(rentalTerms('SUV', '4h')!.price).toBe(1279);
    expect(rentalTerms('CAB', '5h')).toBeNull();
    const q = modeQuote(VehicleKind.CAB, t, { distanceKm: 40, durationMin: 240 });
    expect(q).toMatchObject({ base: 849, total: 849, multiplier: 1, peakCharge: 0 });
    // Inside the package: nothing more.
    expect(settleMode(t, 31.4, 200)).toEqual({ extraKm: 0, extraMin: 0, extraKmCharge: 0, extraTimeCharge: 0 });
    // 46.2 km in 4 h 25 min (and a few seconds): 6.2 km × ₹12 = ₹74, 26 started minutes × ₹2 = ₹52.
    const s = settleMode(t, 46.2, 265.2);
    expect(s).toEqual({ extraKm: 6.2, extraMin: 26, extraKmCharge: 74, extraTimeCharge: 52 });
    expect(withSettlement(q, s).total).toBe(849 + 74 + 52);
    // GPS distance failed: no km charge, time still counts.
    expect(settleMode(t, null, 250).extraKmCharge).toBe(0);
  });
});

describe('outstation', () => {
  const leave = new Date('2026-10-06T00:30:00Z'); // Tue 6:00 am IST

  it('one way: the route km (at least the minimum) at the one-way rate plus a day of allowance, fixed', () => {
    const t = outstationTerms({ kind: 'SEDAN', routeKm: 87.4, roundTrip: false, leaveAt: leave, returnAt: null });
    expect(t).toMatchObject({ roundTrip: false, days: 1, includedKm: 88, perKm: 15, allowancePerDay: 300 });
    expect(modeQuote(VehicleKind.SEDAN, t, { distanceKm: 87.4, durationMin: 120 }).total).toBe(88 * 15 + 300);
    expect(outstationTerms({ kind: 'CAB', routeKm: 22, roundTrip: false, leaveAt: leave, returnAt: null }).includedKm).toBe(60);
    expect(settleMode(t, 140, 600).extraKmCharge).toBe(0);
  });

  it('round trip: 250 km a day included (or twice the route), allowance per calendar day, extra km at the end', () => {
    const back = new Date('2026-10-07T14:30:00Z'); // Wed 8:00 pm IST → 2 days
    expect(istDays(leave, back)).toBe(2);
    expect(istDays(leave, new Date('2026-10-06T16:30:00Z'))).toBe(1); // Tue 10 pm
    const t = outstationTerms({ kind: 'CAB', routeKm: 86, roundTrip: true, leaveAt: leave, returnAt: back });
    expect(t).toMatchObject({ roundTrip: true, days: 2, includedKm: 500, perKm: 11, allowancePerDay: 300 });
    expect(modeQuote(VehicleKind.CAB, t, { distanceKm: 172, durationMin: 240 }).total).toBe(500 * 11 + 600);
    expect(settleMode(t, 512.3, 2000)).toMatchObject({ extraKm: 12.3, extraKmCharge: 135, extraTimeCharge: 0 });
    // A long route: twice the route beats the daily allowance.
    expect(outstationTerms({ kind: 'SUV', routeKm: 300, roundTrip: true, leaveAt: leave, returnAt: leave }).includedKm).toBe(600);
  });
});
