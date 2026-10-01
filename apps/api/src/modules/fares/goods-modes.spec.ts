import { readFileSync } from 'node:fs';

import { VehicleKind } from '../../generated/prisma/enums.js';
import { goodsOutstationTerms, type GoodsTruck, isGoodsTruck, isIstWeekend, type ShiftingDetails, shiftingLines } from './goods-modes.js';
import { modeQuote } from './ride-modes.js';

interface Cases {
  goodsOutstation: { name: string; input: { kind: GoodsTruck; routeKm: number }; expected: { includedKm: number; perKm: number; routeKm: number; total: number } }[];
  shifting: { name: string; input: { details: Omit<ShiftingDetails, 'items'>; transport: number; at: string }; expected: Record<string, number> }[];
}

const cases = JSON.parse(
  readFileSync(new URL('../../../../../packages/tamiltaxi_data/test/fixtures/goods_mode_cases.json', import.meta.url), 'utf8'),
) as Cases;

describe('goods to another town', () => {
  it('goes by goods trucks only, not the goods bike', () => {
    expect(isGoodsTruck(VehicleKind.THREE_WHEELER)).toBe(true);
    expect(isGoodsTruck(VehicleKind.TRUCK)).toBe(true);
    expect(isGoodsTruck(VehicleKind.GOODS_BIKE)).toBe(false);
    expect(isGoodsTruck(VehicleKind.CAB)).toBe(false);
  });

  it.each(cases.goodsOutstation)('$name (shared case)', ({ input, expected }) => {
    const t = goodsOutstationTerms(input.kind, input.routeKm);
    expect(t).toMatchObject({ mode: 'OUTSTATION', roundTrip: false, days: 1, allowancePerDay: 0, includedKm: expected.includedKm, perKm: expected.perKm, routeKm: expected.routeKm });
    expect(modeQuote(input.kind as VehicleKind, t, { distanceKm: input.routeKm, durationMin: 120 }).total).toBe(expected.total);
  });
});

describe('house shifting', () => {
  it.each(cases.shifting)('$name (shared case)', ({ input, expected }) => {
    expect(shiftingLines(input.details, input.transport, new Date(input.at))).toEqual(expected);
  });

  it('weekends are Saturday and Sunday in India, whatever the server clock', () => {
    expect(isIstWeekend(new Date('2026-10-02T18:29:00Z'))).toBe(false); // Fri 11:59 pm IST
    expect(isIstWeekend(new Date('2026-10-02T18:31:00Z'))).toBe(true); // Sat 12:01 am IST
    expect(isIstWeekend(new Date('2026-10-04T18:29:00Z'))).toBe(true); // Sun 11:59 pm IST
    expect(isIstWeekend(new Date('2026-10-04T18:31:00Z'))).toBe(false); // Mon 12:01 am IST
  });
});
