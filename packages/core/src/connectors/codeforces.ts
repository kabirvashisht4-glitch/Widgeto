/**
 * Codeforces connector — the only source with true timestamps.
 *
 * Codeforces has a real, documented, anonymous public API, and `user.status`
 * returns a `creationTimeSeconds` per submission. That means we can bucket
 * activity into genuine local days instead of inheriting somebody else's UTC
 * grid, so this connector reports `precision: 'exact'`.
 *
 * Codeforces has no notion of a streak; it is derived here from submissions.
 * Rate limit is roughly one call every two seconds per origin, which is why
 * the API layer caches aggressively rather than polling per widget refresh.
 */
import type { DayCount, FetchContext, PlatformResult, Stat } from '../types.ts';
import { ConnectorError, getJson } from '../util/http.ts';
import { addDays, daysBetween, localDateFromSeconds, today } from '../util/time.ts';

const API = 'https://codeforces.com/api';

/** Codeforces rank colours, so the widget can show a handle in its real tier. */
const RANK_COLORS: Record<string, string> = {
  'newbie': '#808080',
  'pupil': '#008000',
  'specialist': '#03a89e',
  'expert': '#0000ff',
  'candidate master': '#aa00aa',
  'master': '#ff8c00',
  'international master': '#ff8c00',
  'grandmaster': '#ff0000',
  'international grandmaster': '#ff0000',
  'legendary grandmaster': '#ff0000',
};

interface CfEnvelope<T> {
  status: 'OK' | 'FAILED';
  comment?: string;
  result: T;
}

interface CfUser {
  handle: string;
  firstName?: string;
  lastName?: string;
  avatar?: string;
  titlePhoto?: string;
  rating?: number;
  maxRating?: number;
  rank?: string;
  maxRank?: string;
  friendOfCount?: number;
}

interface CfSubmission {
  id: number;
  creationTimeSeconds: number;
  verdict?: string;
  problem: { name: string; rating?: number };
}

async function cfCall<T>(path: string, ctx: FetchContext): Promise<T> {
  const body = await getJson<CfEnvelope<T>>(`${API}/${path}`, {
    headers: { 'User-Agent': 'Widgeto' },
    fetchImpl: ctx.fetchImpl,
    timeoutMs: ctx.timeoutMs,
  });
  if (body.status !== 'OK') throw new ConnectorError(body.comment ?? 'Codeforces returned FAILED');
  return body.result;
}

export async function fetchCodeforces(handle: string, ctx: FetchContext): Promise<PlatformResult> {
  const base = {
    platform: 'codeforces' as const,
    handle,
    fetchedAt: new Date().toISOString(),
    precision: 'exact' as const,
  };

  try {
    const cutoff = addDays(today(ctx.timezone), -ctx.days + 1);

    // user.status is newest-first, so we can stop pulling pages once we walk
    // past the window instead of downloading a decade of submissions.
    const [users, submissions] = await Promise.all([
      cfCall<CfUser[]>(`user.info?handles=${encodeURIComponent(handle)}`, ctx),
      collectSubmissions(handle, cutoff, ctx),
    ]);

    const user = users[0];
    if (!user) throw new ConnectorError(`no Codeforces user named "${handle}"`);

    const byDay = new Map<string, number>();
    let solved = 0;
    const solvedProblems = new Set<string>();
    for (const sub of submissions) {
      const date = localDateFromSeconds(sub.creationTimeSeconds, ctx.timezone);
      if (date < cutoff) continue;
      byDay.set(date, (byDay.get(date) ?? 0) + 1);
      if (sub.verdict === 'OK' && !solvedProblems.has(sub.problem.name)) {
        solvedProblems.add(sub.problem.name);
        solved++;
      }
    }

    const days: DayCount[] = [...byDay.entries()]
      .map(([date, count]) => ({ date, count }))
      .sort((a, b) => a.date.localeCompare(b.date));

    const stats: Stat[] = [];
    if (user.rating !== undefined) {
      stats.push({ label: 'rating', value: user.rating, accent: RANK_COLORS[user.rank ?? ''] });
    }
    if (user.maxRating !== undefined) stats.push({ label: 'peak', value: user.maxRating });
    stats.push({ label: 'solved', value: solved });
    if (user.rank) stats.push({ label: 'rank', value: user.rank, accent: RANK_COLORS[user.rank] });

    const name = [user.firstName, user.lastName].filter(Boolean).join(' ');

    return {
      ...base,
      ok: true,
      days,
      profile: {
        handle: user.handle,
        displayName: name || user.handle,
        avatarUrl: user.titlePhoto ?? user.avatar,
        profileUrl: `https://codeforces.com/profile/${user.handle}`,
        stats,
      },
    };
  } catch (err) {
    return { ...base, ok: false, days: [], error: (err as Error).message };
  }
}

/**
 * Page backwards through `user.status` until we pass the window.
 *
 * Capped at a few pages so a prolific account cannot turn one widget refresh
 * into a hundred upstream calls.
 */
async function collectSubmissions(
  handle: string,
  cutoff: string,
  ctx: FetchContext,
): Promise<CfSubmission[]> {
  const PAGE = 500;
  const MAX_PAGES = 6;
  const all: CfSubmission[] = [];

  for (let page = 0; page < MAX_PAGES; page++) {
    const from = page * PAGE + 1;
    const batch = await cfCall<CfSubmission[]>(
      `user.status?handle=${encodeURIComponent(handle)}&from=${from}&count=${PAGE}`,
      ctx,
    );
    all.push(...batch);

    if (batch.length < PAGE) break; // no more submissions at all

    const oldest = batch[batch.length - 1];
    const oldestDate = localDateFromSeconds(oldest.creationTimeSeconds, ctx.timezone);
    if (daysBetween(cutoff, oldestDate) < 0) break; // walked past the window
  }

  return all;
}
