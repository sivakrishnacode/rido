/** Text a spreadsheet would run as a formula ("CSV injection"): starts with = + - @, or a tab / carriage return. */
const FORMULA_START = /^[=+\-@\t\r]/;
/** "+919876543210", "-5": only a number, nothing to run (phones stay readable). */
const PLAIN_NUMBER = /^[+-]?\d[\d.]*$/;

/**
 * One CSV cell. Dates as ISO strings; quoted when it holds a comma, quote or line break. Text that would start a
 * formula (a rider named "=HYPERLINK(…)") gets a leading `'` so Excel / Sheets show it as text. Numbers, and text that
 * is only a number (a phone "+91…"), are left as they are.
 */
export function csvCell(v: unknown): string {
  let s = v instanceof Date ? v.toISOString() : String(v ?? '');
  if (typeof v === 'string' && FORMULA_START.test(s) && !PLAIN_NUMBER.test(s)) s = `'${s}`;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** Rows as CSV with a header line from the first row's keys ('' when there are no rows). */
export function toCsv(rows: readonly Record<string, unknown>[]): string {
  if (rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  return [headers.join(','), ...rows.map((r) => headers.map((h) => csvCell(r[h])).join(','))].join('\n');
}
