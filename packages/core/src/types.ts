/**
 * Widgeto core types.
 *
 * Every connector, no matter how different its upstream API, reduces to the
 * same thing: a sparse list of `DayCount` in the *user's local timezone*.
 * That single shape is the whole abstraction — the streak engine, the API and
 * the widget renderer never learn anything platform-specific.
 */

export type PlatformId = 'github' | 'leetcode' | 'codeforces';

/** A calendar day (`YYYY-MM-DD`, user-local) and how much happened on it. */
export interface DayCount {
  date: string;
  count: number;
}

/**
 * How faithfully a source can be mapped onto local days.
 *
 * - `exact`   — the API gives per-event timestamps, so we bucket into true
 *               local days. Codeforces.
 * - `utc-day` — the API only exposes a UTC calendar grid, so a day's label is
 *               taken as-is. For a user at UTC+5:30 that grid runs 05:30→05:30
 *               local, which means post-midnight work can land on the previous
 *               label. GitHub and LeetCode. Surfaced to the UI rather than
 *               hidden, because it is the #1 source of "your streak is wrong".
 */
export type DayPrecision = 'exact' | 'utc-day';

/** A headline stat a platform is proud of — rating, followers, problems solved. */
export interface Stat {
  label: string;
  value: string | number;
  /** Optional accent for the UI, e.g. a Codeforces rank colour. */
  accent?: string;
}

export interface PlatformProfile {
  handle: string;
  displayName?: string;
  avatarUrl?: string;
  profileUrl: string;
  stats: Stat[];
}

/**
 * The result of asking one platform about one handle.
 *
 * A failure is a value, not an exception: one dead connector must degrade a
 * single row, never take down the widget. `ok: false` still carries the
 * platform and handle so the UI can render a retry affordance in place.
 */
export interface PlatformResult {
  platform: PlatformId;
  handle: string;
  ok: boolean;
  error?: string;
  fetchedAt: string;
  precision: DayPrecision;
  profile?: PlatformProfile;
  /** Sparse, ascending by date. Days with no activity are omitted. */
  days: DayCount[];
}

/** Whether today's box is already filled, still open, or the run is over. */
export type StreakStatus = 'safe' | 'at-risk' | 'broken';

export interface StreakSummary {
  timezone: string;
  /** Today's date in `timezone`. */
  today: string;
  activeToday: boolean;
  status: StreakStatus;
  currentStreak: number;
  longestStreak: number;
  totalActiveDays: number;
  totalContributions: number;
  /** The day the current streak began, or `null` when there is no streak. */
  streakStart: string | null;
}

export interface UnifiedActivity {
  summary: StreakSummary;
  /** Dense, ascending, one entry per day over the requested window. */
  heatmap: DayCount[];
  /** Per-platform breakdown, including failures. */
  platforms: PlatformResult[];
}

/** What the user configured: which platforms, under which handles. */
export interface HandleMap {
  github?: string;
  leetcode?: string;
  codeforces?: string;
}

export interface FetchContext {
  /** IANA zone, e.g. `Asia/Kolkata`. Drives every day boundary. */
  timezone: string;
  /** How many days of history to pull. */
  days: number;
  /** GitHub needs a token even for public contribution calendars. */
  githubToken?: string;
  /** Injectable for tests and for Workers' fetch. */
  fetchImpl?: typeof fetch;
  /** Per-request timeout in ms. */
  timeoutMs?: number;
}
