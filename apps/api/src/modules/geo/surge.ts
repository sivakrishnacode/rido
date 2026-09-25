/** Demand level shown to drivers ("High demand") and in the admin panel. */
export type DemandLevel = 'normal' | 'busy' | 'high';

/**
 * Surge from live demand vs supply in one hexagon.
 * ratio = requests ÷ free drivers (at least 1); multiplier = 1 + sensitivity × (ratio − 1), capped,
 * rounded down to 0.05. Below [minRequests] there is no surge (too little signal).
 */
export function surgeFor(p: { requests: number; freeDrivers: number; sensitivity: number; minRequests: number; maxMultiplier: number }): {
  ratio: number;
  multiplier: number;
  level: DemandLevel;
} {
  const ratio = p.requests / Math.max(1, p.freeDrivers);
  if (p.requests < p.minRequests || ratio <= 1) return { ratio, multiplier: 1, level: p.requests >= p.minRequests ? 'busy' : 'normal' };
  const raw = Math.min(p.maxMultiplier, 1 + p.sensitivity * (ratio - 1));
  const multiplier = Math.floor(raw * 20 + 1e-9) / 20;
  return { ratio, multiplier, level: multiplier >= 1.2 || ratio >= 3 ? 'high' : 'busy' };
}

/**
 * Smooths surge across neighbouring hexes (Uber H3 practice: avoid sharp price cliffs at cell edges).
 * For every cell with surge and its ring-1 neighbours: smoothed = own × (1 − w) + mean(neighbours) × w,
 * never below the cell's own value × (1 − w) + w, rounded down to 0.05. Returns cells with multiplier > 1.
 */
export function smoothSurge(raw: ReadonlyMap<string, number>, neighbours: (cell: string) => string[], weight = 0.4): Map<string, number> {
  const candidates = new Set<string>();
  for (const [cell, m] of raw) {
    if (m <= 1) continue;
    candidates.add(cell);
    for (const n of neighbours(cell)) candidates.add(n);
  }
  const out = new Map<string, number>();
  for (const cell of candidates) {
    const around = neighbours(cell).filter((n) => n !== cell);
    const mean = around.length ? around.reduce((a, n) => a + (raw.get(n) ?? 1), 0) / around.length : 1;
    const own = raw.get(cell) ?? 1;
    const v = Math.floor((own * (1 - weight) + mean * weight) * 20 + 1e-9) / 20;
    if (v > 1) out.set(cell, v);
  }
  return out;
}
