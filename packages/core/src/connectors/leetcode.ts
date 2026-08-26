/**
 * LeetCode connector — the fragile one, treated as such.
 *
 * LeetCode publishes no official API. This uses the same public GraphQL
 * endpoint the site's own frontend calls, reading only data that is already
 * visible on a public profile. Consequences we design around:
 *
 *  - It can break or start refusing us at any time, so failure is a normal
 *    return value and the widget degrades to its other rows.
 *  - It is Cloudflare-fronted, so requests must look like a browser and stay
 *    infrequent. Never put this connector behind a per-refresh poll.
 *  - `userCalendar` is scoped to a single year and its own `streak` field is
 *    per-year and UTC-based, so we ignore it and recompute from the raw
 *    calendar — otherwise a streak spanning New Year silently resets.
 *
 * We never ask for a password or session cookie. Public profile only.
 */
import type { DayCount, FetchContext, PlatformResult, Stat } from '../types.ts';
import { ConnectorError, postJson } from '../util/http.ts';
import { addDays, localDateFromSeconds, today } from '../util/time.ts';

const ENDPOINT = 'https://leetcode.com/graphql';

const QUERY = `
query($username: String!, $year: Int) {
  matchedUser(username: $username) {
    username
    profile { realName userAvatar ranking }
    submitStatsGlobal { acSubmissionNum { difficulty count } }
    userCalendar(year: $year) { activeYears submissionCalendar }
  }
}`;

interface LcReply {
  data?: {
    matchedUser: {
      username: string;
      profile: { realName: string | null; userAvatar: string | null; ranking: number | null };
      submitStatsGlobal: { acSubmissionNum: { difficulty: string; count: number }[] };
      userCalendar: { activeYears: number[]; submissionCalendar: string };
    } | null;
  };
  errors?: { message: string }[];
}

/** Browser-shaped headers; a bare client gets challenged by Cloudflare. */
const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36',
  Referer: 'https://leetcode.com/',
  Origin: 'https://leetcode.com',
};

async function fetchYear(username: string, year: number, ctx: FetchContext): Promise<LcReply> {
  const reply = await postJson<LcReply>(
    ENDPOINT,
    { query: QUERY, variables: { username, year } },
    { headers: HEADERS, fetchImpl: ctx.fetchImpl, timeoutMs: ctx.timeoutMs },
  );
  if (reply.errors?.length) throw new ConnectorError(reply.errors.map((e) => e.message).join('; '));
  return reply;
}

export async function fetchLeetCode(handle: string, ctx: FetchContext): Promise<PlatformResult> {
  const base = {
    platform: 'leetcode' as const,
    handle,
    fetchedAt: new Date().toISOString(),
    // submissionCalendar keys are UTC midnights — no finer signal is exposed.
    precision: 'utc-day' as const,
  };

  try {
    const end = today(ctx.timezone);
    const start = addDays(end, -ctx.days + 1);

    // A window can straddle New Year, and userCalendar is per-year, so ask for
    // every year the window touches and merge.
    const years = new Set<number>([Number(start.slice(0, 4)), Number(end.slice(0, 4))]);
    const replies = await Promise.all([...years].map((y) => fetchYear(handle, y, ctx)));

    const user = replies[0].data?.matchedUser;
    if (!user) throw new ConnectorError(`no LeetCode user named "${handle}"`);

    const byDay = new Map<string, number>();
    for (const reply of replies) {
      const raw = reply.data?.matchedUser?.userCalendar?.submissionCalendar;
      if (!raw) continue;
      let parsed: Record<string, number>;
      try {
        parsed = JSON.parse(raw);
      } catch {
        continue; // a malformed year should not sink the others
      }
      for (const [seconds, count] of Object.entries(parsed)) {
        const date = localDateFromSeconds(Number(seconds), 'UTC');
        if (date < start || date > end) continue;
        byDay.set(date, (byDay.get(date) ?? 0) + count);
      }
    }

    const days: DayCount[] = [...byDay.entries()]
      .map(([date, count]) => ({ date, count }))
      .sort((a, b) => a.date.localeCompare(b.date));

    const solvedBy = new Map(
      user.submitStatsGlobal.acSubmissionNum.map((s) => [s.difficulty.toLowerCase(), s.count]),
    );
    const stats: Stat[] = [
      { label: 'solved', value: solvedBy.get('all') ?? 0 },
      { label: 'easy', value: solvedBy.get('easy') ?? 0, accent: '#00b8a3' },
      { label: 'medium', value: solvedBy.get('medium') ?? 0, accent: '#ffb800' },
      { label: 'hard', value: solvedBy.get('hard') ?? 0, accent: '#ff375f' },
    ];
    if (user.profile.ranking) stats.push({ label: 'rank', value: `#${user.profile.ranking.toLocaleString()}` });

    return {
      ...base,
      ok: true,
      days,
      profile: {
        handle: user.username,
        displayName: user.profile.realName || user.username,
        avatarUrl: user.profile.userAvatar ?? undefined,
        profileUrl: `https://leetcode.com/u/${user.username}/`,
        stats,
      },
    };
  } catch (err) {
    return { ...base, ok: false, days: [], error: (err as Error).message };
  }
}
