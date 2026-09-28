/** A driver's rating: the mean of the ratings passengers gave (2 decimals); [fallback] until the first one. */
export function averageRating(params: { sum: number; count: number; fallback?: number }): number {
  if (params.count <= 0) return params.fallback ?? 5;
  return Math.round((params.sum / params.count) * 100) / 100;
}
