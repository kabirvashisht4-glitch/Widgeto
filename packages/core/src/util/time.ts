/**
 * Day-boundary arithmetic.
 *
 * Everything in Widgeto is keyed by a `YYYY-MM-DD` string in the user's own
 * timezone. Streaks are the one feature where an off-by-one hour is not a
 * rounding error but a broken promise, so all conversion happens here and
 * nowhere else.
 */

/** `YYYY-MM-DD` for an instant, as seen from `tz`. */
export function localDate(epochMs: number, tz: string): string {
  // en-CA formats as YYYY-MM-DD, which saves hand-assembling parts.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(epochMs));
}

export function localDateFromSeconds(epochSeconds: number, tz: string): string {
  return localDate(epochSeconds * 1000, tz);
}

/** Today in `tz`. */
export function today(tz: string, now: number = Date.now()): string {
  return localDate(now, tz);
}

/**
 * Shift a date string by whole days.
 *
 * Anchored at UTC noon so that adding a day can never be swallowed by a DST
 * transition — the 12-hour cushion absorbs any ±1h shift.
 */
export function addDays(date: string, delta: number): string {
  const [y, m, d] = date.split('-').map(Number);
  const anchor = Date.UTC(y, m - 1, d, 12, 0, 0);
  const moved = new Date(anchor + delta * 86_400_000);
  return moved.toISOString().slice(0, 10);
}

/** Whole days from `from` to `to`; negative when `to` is earlier. */
export function daysBetween(from: string, to: string): number {
  const parse = (s: string) => {
    const [y, m, d] = s.split('-').map(Number);
    return Date.UTC(y, m - 1, d, 12, 0, 0);
  };
  return Math.round((parse(to) - parse(from)) / 86_400_000);
}

/** Every date from `start` to `end`, inclusive, ascending. */
export function dateRange(start: string, end: string): string[] {
  const out: string[] = [];
  const span = daysBetween(start, end);
  for (let i = 0; i <= span; i++) out.push(addDays(start, i));
  return out;
}

/** Validate an IANA zone, falling back to UTC rather than throwing. */
export function safeTimezone(tz: string | undefined): string {
  if (!tz) return 'UTC';
  try {
    new Intl.DateTimeFormat('en-CA', { timeZone: tz });
    return tz;
  } catch {
    return 'UTC';
  }
}
