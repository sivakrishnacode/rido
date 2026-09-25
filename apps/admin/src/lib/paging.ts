/** Query values accepted by list pages and the admin API (?page&pageSize&q&status&kind). */
export type QueryValue = string | number | boolean | null | undefined;
export type QueryInput = Record<string, QueryValue | QueryValue[]>;

export const DEFAULT_PAGE_SIZE = 20;

/**
 * Builds "path?a=1&b=2", skipping empty values (undefined, null, "", "ALL") so URLs stay clean.
 * Keys are kept in insertion order.
 */
export function withQuery(path: string, query: QueryInput = {}): string {
  const params = new URLSearchParams();
  for (const [key, raw] of Object.entries(query)) {
    const values = Array.isArray(raw) ? raw : [raw];
    for (const value of values) {
      if (value === undefined || value === null || value === "" || value === "ALL") continue;
      params.append(key, String(value));
    }
  }
  const qs = params.toString();
  return qs ? `${path}?${qs}` : path;
}

/** Link to another page of the same list, keeping the current filters. page 1 is omitted. */
export function pageHref(path: string, current: QueryInput, page: number): string {
  return withQuery(path, { ...current, page: page > 1 ? page : undefined });
}

/** Reads a positive integer page from a search param, defaulting to 1. */
export function parsePage(value: string | string[] | undefined): number {
  const n = Number(Array.isArray(value) ? value[0] : value);
  return Number.isInteger(n) && n >= 1 ? n : 1;
}

/** First value of a search param. */
export function param(value: string | string[] | undefined): string | undefined {
  const v = Array.isArray(value) ? value[0] : value;
  return v?.trim() || undefined;
}

export interface PageInfo {
  readonly page: number;
  readonly pageCount: number;
  readonly from: number;
  readonly to: number;
  readonly hasPrev: boolean;
  readonly hasNext: boolean;
}

/** "Showing 21–40 of 57" numbers and prev/next flags. */
export function pageInfo(p: { page: number; pageSize: number; total: number }): PageInfo {
  const pageCount = Math.max(1, Math.ceil(p.total / p.pageSize));
  const from = p.total === 0 ? 0 : (p.page - 1) * p.pageSize + 1;
  const to = Math.min(p.total, p.page * p.pageSize);
  return { page: p.page, pageCount, from, to, hasPrev: p.page > 1, hasNext: p.page < pageCount };
}

/** Compact page list with gaps: [1, "…", 4, 5, 6, "…", 10]. */
export function pageWindow(page: number, pageCount: number): (number | "…")[] {
  if (pageCount <= 7) return Array.from({ length: pageCount }, (_, i) => i + 1);
  const pages = new Set([1, pageCount, page - 1, page, page + 1].filter((n) => n >= 1 && n <= pageCount));
  const sorted = [...pages].sort((a, b) => a - b);
  const out: (number | "…")[] = [];
  sorted.forEach((n, i) => {
    if (i > 0 && n - sorted[i - 1] > 1) out.push("…");
    out.push(n);
  });
  return out;
}
