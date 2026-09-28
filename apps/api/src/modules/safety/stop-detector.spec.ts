import { STOP_AWAY_FROM_ENDS_M, type StopAnchor, stepStop } from './stop-detector.js';

const PICKUP = { lat: 11.0183, lng: 76.9725 };
const DROP = { lat: 11.009, lng: 76.96 };
/** Mid-route, ~700 m from both ends. */
const MID = { lat: 11.0137, lng: 76.9663 };
const CFG = { radiusM: 30, minutes: 4 };
const T0 = Date.UTC(2026, 8, 28, 10);
/** ~[m] metres north of [p]. */
const north = (p: { lat: number; lng: number }, m: number) => ({ lat: p.lat + m / 111_320, lng: p.lng });

/** Feeds fixes every [everyS] seconds for [forS] seconds at [at] (with [jitterM] of GPS noise), returns the steps. */
function standAt(at: { lat: number; lng: number }, forS: number, everyS = 5, jitterM = 8, start: StopAnchor | null = null) {
  let anchor = start;
  const steps = [];
  for (let s = 0; s <= forS; s += everyS) {
    const step = stepStop(anchor, { ...north(at, (s / everyS) % 2 ? jitterM : -jitterM), ts: T0 + s * 1000 }, { pickup: PICKUP, drop: DROP }, CFG);
    anchor = step.anchor;
    steps.push(step);
  }
  return steps;
}

describe('stepStop', () => {
  it('flags standing within 30 m for 4 min away from pickup and drop', () => {
    const steps = standAt(MID, 5 * 60);
    const firstStop = steps.findIndex((s) => s.isStop);
    // 4 min after the first fix (fixes every 5 s): the 49th fix.
    expect(firstStop).toBe(48);
    expect(steps[firstStop].stoppedMs).toBe(4 * 60_000);
    expect(steps.slice(0, firstStop).every((s) => !s.isStop)).toBe(true);
  });

  it('not before 4 min, and not while moving', () => {
    expect(standAt(MID, 3 * 60 + 55).some((s) => s.isStop)).toBe(false);
    // Crawling 40 m every 5 s: the anchor keeps moving.
    let anchor: StopAnchor | null = null;
    for (let i = 0; i < 100; i++) {
      const step = stepStop(anchor, { ...north(MID, i * 40), ts: T0 + i * 5000 }, { pickup: PICKUP, drop: DROP }, CFG);
      expect(step.isStop).toBe(false);
      anchor = step.anchor;
    }
  });

  it('ignores waiting near the pickup or the drop', () => {
    expect(standAt(north(PICKUP, 100), 10 * 60).some((s) => s.isStop)).toBe(false);
    expect(standAt(north(DROP, STOP_AWAY_FROM_ENDS_M - 20), 10 * 60).some((s) => s.isStop)).toBe(false);
    expect(standAt(north(DROP, STOP_AWAY_FROM_ENDS_M + 60), 10 * 60).some((s) => s.isStop)).toBe(true);
  });

  it('a late (older) fix far away never moves the anchor back in time', () => {
    const anchor = { ...MID, t: T0 };
    const step = stepStop(anchor, { ...north(MID, 500), ts: T0 - 60_000 }, { pickup: PICKUP, drop: DROP }, CFG);
    expect(step.anchor).toBe(anchor);
    expect(step.isStop).toBe(false);
  });
});
