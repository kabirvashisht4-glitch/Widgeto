/**
 * The unified streak.
 *
 * The product idea in one function: it does not matter *where* you coded, only
 * *that* you did. Every platform's days collapse into one timeline, and one
 * number comes out.
 *
 * The rule that matters most is what happens on an empty today. A naive
 * implementation breaks your streak at 00:00 and shows a 0 for the rest of the
 * day, which is both wrong and demoralising — the day is not over. So today is
 * treated as *pending*: the streak stays alive and is reported `at-risk` until
 * either activity lands or the day actually ends.
 */
import type { DayCount, StreakStatus, StreakSummary } from './types.ts';
import { addDays, dateRange, today as todayIn } from './util/time.ts';

/** Collapse many platforms' sparse day lists into one date → count map. */
export function mergeDays(sources: DayCount[][]): Map<string, number> {
  const merged = new Map<string, number>();
  for (const days of sources) {
    for (const { date, count } of days) {
      if (count > 0) merged.set(date, (merged.get(date) ?? 0) + count);
    }
  }
  return merged;
}

export interface StreakOptions {
  timezone: string;
  /** Overridable so tests are not hostage to the wall clock. */
  now?: number;
}

export function computeStreak(
  merged: Map<string, number>,
  { timezone, now = Date.now() }: StreakOptions,
): StreakSummary {
  const today = todayIn(timezone, now);
  const yesterday = addDays(today, -1);
  const activeToday = (merged.get(today) ?? 0) > 0;

  // Walk backwards from today (if it counts) or yesterday (if today is still
  // open) until a gap appears.
  let cursor = activeToday ? today : yesterday;
  let currentStreak = 0;
  let streakStart: string | null = null;
  while ((merged.get(cursor) ?? 0) > 0) {
    currentStreak++;
    streakStart = cursor;
    cursor = addDays(cursor, -1);
  }

  const status: StreakStatus = activeToday ? 'safe' : currentStreak > 0 ? 'at-risk' : 'broken';

  return {
    timezone,
    today,
    activeToday,
    status,
    currentStreak,
    longestStreak: longestRun(merged),
    totalActiveDays: merged.size,
    totalContributions: [...merged.values()].reduce((a, b) => a + b, 0),
    streakStart,
  };
}

/** Longest consecutive run of active days anywhere in the data. */
function longestRun(merged: Map<string, number>): number {
  const active = [...merged.keys()].filter((d) => (merged.get(d) ?? 0) > 0).sort();
  if (active.length === 0) return 0;

  let best = 1;
  let run = 1;
  for (let i = 1; i < active.length; i++) {
    // Consecutive iff the previous date plus one day equals this date.
    run = addDays(active[i - 1], 1) === active[i] ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}

/**
 * Expand the sparse map into a dense, gap-filled series for the heatmap.
 * The UI should never have to reason about missing days.
 */
export function buildHeatmap(merged: Map<string, number>, days: number, timezone: string, now = Date.now()): DayCount[] {
  const end = todayIn(timezone, now);
  const start = addDays(end, -days + 1);
  return dateRange(start, end).map((date) => ({ date, count: merged.get(date) ?? 0 }));
}

/**
 * Bucket a count into the 0-4 intensity levels a contribution grid uses.
 * Thresholds are relative to the user's own busiest day, so a casual user's
 * grid is as legible as a maintainer's instead of being uniformly pale.
 */
export function intensityLevels(heatmap: DayCount[]): number[] {
  const peak = Math.max(1, ...heatmap.map((d) => d.count));
  return heatmap.map(({ count }) => {
    if (count <= 0) return 0;
    const ratio = count / peak;
    if (ratio > 0.66) return 4;
    if (ratio > 0.33) return 3;
    if (ratio > 0.12) return 2;
    return 1;
  });
}
