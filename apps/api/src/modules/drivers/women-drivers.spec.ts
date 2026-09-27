import { WomenDriverPref } from '../../generated/prisma/enums.js';
import { applyWomenPref, PREFERRED_HEAD_START_MIN } from './women-drivers.js';

const cands = [
  { driverId: 'man', etaMin: 2 },
  { driverId: 'woman', etaMin: 6 },
];
const women = new Set(['woman']);

describe('applyWomenPref (Butterfly)', () => {
  it('NONE changes nothing', () => {
    expect(applyWomenPref(cands, WomenDriverPref.NONE, women)).toEqual(cands);
  });

  it('ONLY keeps women drivers only', () => {
    expect(applyWomenPref(cands, WomenDriverPref.ONLY, women).map((c) => c.driverId)).toEqual(['woman']);
    expect(applyWomenPref(cands, WomenDriverPref.ONLY, new Set())).toEqual([]);
  });

  it('PREFERRED ranks a slightly further woman first but keeps men as a fallback', () => {
    const ranked = applyWomenPref(cands, WomenDriverPref.PREFERRED, women).sort((a, b) => a.etaMin - b.etaMin);
    expect(ranked.map((c) => c.driverId)).toEqual(['woman', 'man']);
    expect(ranked[1].etaMin).toBe(2 + PREFERRED_HEAD_START_MIN);
  });

  it('PREFERRED still picks a much closer man when no woman is near', () => {
    const far = [{ driverId: 'man', etaMin: 2 }, { driverId: 'woman', etaMin: 2 + PREFERRED_HEAD_START_MIN + 5 }];
    const ranked = applyWomenPref(far, WomenDriverPref.PREFERRED, women).sort((a, b) => a.etaMin - b.etaMin);
    expect(ranked[0].driverId).toBe('man');
  });
});
