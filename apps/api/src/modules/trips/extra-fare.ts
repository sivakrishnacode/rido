/**
 * "Add extra" (like Rapido's): while nobody has taken the trip, the rider can add a few rupees on top of the quote
 * (+₹10, +₹20, …). It is a line of the stored fare (`extra`), in the total, and goes to the driver like the rest.
 */

/** The steps the rider app offers. */
export const EXTRA_STEPS = [10, 20, 30] as const;

/** The most a rider can add in all: half the quote (to ₹10), at least ₹100. */
export function maxExtra(quoteTotal: number): number {
  return Math.max(100, Math.round(quoteTotal / 20) * 10);
}

/** The extra on a stored fare (0 when there is none). */
export function extraOf(fare: unknown): number {
  const v = fare && typeof fare === 'object' ? (fare as { extra?: unknown }).extra : undefined;
  return typeof v === 'number' && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;
}

/** [fare] with its extra line set to [extra] (replacing any earlier one); the total moves by the difference. */
export function withExtra<T extends { total: number; extra?: number }>(fare: T, extra: number): T & { extra: number } {
  const was = fare.extra ?? 0;
  return { ...fare, extra, total: fare.total - was + extra };
}

/** Why the rider can't set the extra to [amount] on a quote of [quoteTotal] that already has [was]; null = fine. */
export function extraProblem(p: { amount: number; was: number; quoteTotal: number }): string | null {
  if (!Number.isInteger(p.amount) || p.amount <= 0) return 'Add a whole number of rupees';
  if (p.amount <= p.was) return `You already added ₹${p.was}`;
  const cap = maxExtra(p.quoteTotal);
  return p.amount > cap ? `You can add up to ₹${cap}` : null;
}
