/**
 * AtCoder connector.
 *
 * AtCoder publishes no API of its own, so this uses the long-running community
 * mirror at kenkoooo.com, which the Japanese competitive-programming community
 * has depended on for years. It is not first-party, but unlike scraping a page
 * it is a documented JSON service with a stated rate limit.
 *
 * Submissions carry `epoch_second`, so — like Codeforces and unlike GitHub or
 * LeetCode — days can be bucketed into the user's true local time.
 */
import type { DayCount, FetchContext, PlatformResult, Stat } from '../types.ts';
import { ConnectorError, getJson } from '../util/http.ts';
import { addDays, localDateFromSeconds, today } from '../util/time.ts';

const API = 'https://kenkoooo.com/atcoder/atcoder-api';

interface AcSubmission {
  id: number;
  epoch_second: number;
  problem_id: string;
  user_id: string;
  result: string;
  point: number;
}

interface AcUserInfo {
  user_id: string;
  accepted_count: number;
  accepted_count_rank: number;
  rated_point_sum: number;
  rated_point_sum_rank: number;
}

/** Unix seconds for local midnight `days` ago — the API pages from a timestamp. */
function windowStart(ctx: FetchContext): number {
  const start = addDays(today(ctx.timezone), -ctx.days + 1);
  return Math.floor(Date.parse(`${start}T00:00:00Z`) / 1000);
}

export async function fetchAtCoder(handle: string, ctx: FetchContext): Promise<PlatformResult> {
  const base = {
    platform: 'atcoder' as const,
    handle,
    fetchedAt: new Date().toISOString(),
    precision: 'exact' as const,
  };

  try {
    const headers = { 'User-Agent': 'Widgeto', 'Accept-Encoding': 'gzip' };
    const from = windowStart(ctx);

    const [info, submissions] = await Promise.all([
      getJson<AcUserInfo>(`${API}/v3/user_info?user=${encodeURIComponent(handle)}`, {
        headers,
        fetchImpl: ctx.fetchImpl,
        timeoutMs: ctx.timeoutMs,
      }),
      collect(handle, from, ctx, headers),
    ]);

    // kenkoooo answers for unknown users with a zeroed record rather than a
    // 404, so an empty history plus no solves is how "no such user" arrives.
    if (info.accepted_count === 0 && submissions.length === 0) {
      throw new ConnectorError(`no AtCoder user named "${handle}"`);
    }

    const cutoff = addDays(today(ctx.timezone), -ctx.days + 1);
    const byDay = new Map<string, number>();
    for (const sub of submissions) {
      const date = localDateFromSeconds(sub.epoch_second, ctx.timezone);
      if (date < cutoff) continue;
      byDay.set(date, (byDay.get(date) ?? 0) + 1);
    }

    const days: DayCount[] = [...byDay.entries()]
      .map(([date, count]) => ({ date, count }))
      .sort((a, b) => a.date.localeCompare(b.date));

    const stats: Stat[] = [
      { label: 'solved', value: info.accepted_count },
      { label: 'rank', value: `#${info.accepted_count_rank.toLocaleString()}` },
      { label: 'points', value: Math.round(info.rated_point_sum).toLocaleString() },
    ];

    return {
      ...base,
      ok: true,
      days,
      profile: {
        handle: info.user_id || handle,
        displayName: info.user_id || handle,
        profileUrl: `https://atcoder.jp/users/${handle}`,
        stats,
      },
    };
  } catch (err) {
    return { ...base, ok: false, days: [], error: (err as Error).message };
  }
}

/**
 * kenkoooo returns at most 500 submissions per call, oldest first, and asks
 * callers to page by advancing the timestamp rather than hammering it.
 */
async function collect(
  handle: string,
  from: number,
  ctx: FetchContext,
  headers: Record<string, string>,
): Promise<AcSubmission[]> {
  const MAX_PAGES = 8;
  const all: AcSubmission[] = [];
  let cursor = from;

  for (let page = 0; page < MAX_PAGES; page++) {
    const batch = await getJson<AcSubmission[]>(
      `${API}/v3/user/submissions?user=${encodeURIComponent(handle)}&from_second=${cursor}`,
      { headers, fetchImpl: ctx.fetchImpl, timeoutMs: ctx.timeoutMs },
    );
    if (batch.length === 0) break;
    all.push(...batch);
    if (batch.length < 500) break;

    // Advance past the last submission; +1 avoids re-fetching it forever.
    const newest = batch[batch.length - 1].epoch_second;
    if (newest <= cursor) break;
    cursor = newest + 1;
  }

  return all;
}
