/**
 * Stack Overflow connector.
 *
 * Uses the official Stack Exchange API, which is the third first-party source
 * here and the only one that reports *every* kind of contribution — questions,
 * answers, comments, edits, badges — through one timeline endpoint. Each event
 * carries a unix `creation_date`, so days are bucketed into the user's real
 * timezone rather than inherited from someone else's UTC grid.
 *
 * Two things shape this connector:
 *
 *  - **Users are numbers, not names.** Stack Exchange identifies people by a
 *    numeric id; display names are neither unique nor stable. So the handle is
 *    the id, which is what a profile URL already contains
 *    (`stackoverflow.com/users/22656/jon-skeet` → `22656`).
 *
 *  - **The quota is small.** 300 requests per day per IP without a key, 10,000
 *    with one. That is the tightest budget of any connector here, so this asks
 *    for the whole window in as few calls as it can and stops early.
 */
import type { DayCount, FetchContext, PlatformResult, Stat } from '../types.ts';
import { ConnectorError, request } from '../util/http.ts';
import { addDays, localDateFromSeconds, today } from '../util/time.ts';

const API = 'https://api.stackexchange.com/2.3';
const SITE = 'stackoverflow';

interface SeWrapper<T> {
  items: T[];
  has_more: boolean;
  quota_remaining?: number;
  error_message?: string;
  /**
   * Seconds Stack Exchange requires you to wait before calling the same method
   * again. This is not advisory: ignoring it earns a 400 ("Violation of
   * backoff parameter") and then a 429.
   */
  backoff?: number;
}

/**
 * One call, honouring the backoff contract.
 *
 * Errors arrive as a JSON body with `error_message` even on a 4xx, so the body
 * is read before the status is judged — otherwise every failure reads as a
 * bare "upstream returned 400" and says nothing about why.
 */
async function seCall<T>(
  url: string,
  ctx: FetchContext,
  headers: Record<string, string>,
): Promise<SeWrapper<T>> {
  const res = await request(url, {
    headers,
    fetchImpl: ctx.fetchImpl,
    timeoutMs: ctx.timeoutMs,
  });

  let body: SeWrapper<T>;
  try {
    body = (await res.json()) as SeWrapper<T>;
  } catch {
    throw new ConnectorError(`Stack Exchange returned ${res.status}`);
  }

  if (body.error_message) throw new ConnectorError(body.error_message);
  if (!res.ok) throw new ConnectorError(`Stack Exchange returned ${res.status}`);

  // Respect the backoff before the caller makes its next request. Capped so a
  // hostile value cannot stall a widget refresh indefinitely.
  if (typeof body.backoff === 'number' && body.backoff > 0) {
    await new Promise((r) => setTimeout(r, Math.min(body.backoff! * 1000, 5_000)));
  }

  return body;
}

interface SeUser {
  user_id: number;
  display_name: string;
  reputation: number;
  profile_image?: string;
  link: string;
  badge_counts?: { gold: number; silver: number; bronze: number };
}

interface SeTimelineItem {
  creation_date: number;
  timeline_type: string;
}

/**
 * The handle must be the numeric id. A display name is ambiguous — searching
 * "jonskeet" returns a different person than the famous one — and silently
 * charting a stranger's activity is worse than refusing.
 */
function asUserId(handle: string): number | null {
  const trimmed = handle.trim();
  if (!/^\d+$/.test(trimmed)) return null;
  const id = Number(trimmed);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function withKey(url: string, ctx: FetchContext): string {
  // An optional key raises the daily quota from 300 to 10,000. It is not a
  // secret in the usual sense — Stack Exchange treats it as an app identifier
  // — but it still only ever lives server-side.
  const key = ctx.stackExchangeKey;
  return key ? `${url}&key=${encodeURIComponent(key)}` : url;
}

export async function fetchStackOverflow(
  handle: string,
  ctx: FetchContext,
): Promise<PlatformResult> {
  const base = {
    platform: 'stackoverflow' as const,
    handle,
    fetchedAt: new Date().toISOString(),
    precision: 'exact' as const,
  };

  try {
    const userId = asUserId(handle);
    if (userId === null) {
      throw new ConnectorError(
        `Stack Overflow needs your numeric user id, not a display name — ` +
          `it is the number in your profile URL, e.g. /users/22656/…`,
      );
    }

    const start = addDays(today(ctx.timezone), -ctx.days + 1);
    const fromDate = Math.floor(Date.parse(`${start}T00:00:00Z`) / 1000);
    const headers = { 'User-Agent': 'Widgeto', 'Accept-Encoding': 'gzip' };

    // Sequential, not parallel: two concurrent calls to the same API are
    // exactly what trips the backoff, and the second one then fails for a
    // reason that has nothing to do with the user.
    const profile = await seCall<SeUser>(
      withKey(`${API}/users/${userId}?site=${SITE}&filter=default`, ctx),
      ctx,
      headers,
    );
    const events = await collectTimeline(userId, fromDate, ctx, headers);

    const user = profile.items?.[0];
    if (!user) throw new ConnectorError(`no Stack Overflow user with id ${userId}`);

    const cutoff = start;
    const byDay = new Map<string, number>();
    for (const event of events) {
      const date = localDateFromSeconds(event.creation_date, ctx.timezone);
      if (date < cutoff) continue;
      byDay.set(date, (byDay.get(date) ?? 0) + 1);
    }

    const days: DayCount[] = [...byDay.entries()]
      .map(([date, count]) => ({ date, count }))
      .sort((a, b) => a.date.localeCompare(b.date));

    const badges = user.badge_counts;
    const stats: Stat[] = [
      { label: 'reputation', value: user.reputation.toLocaleString() },
    ];
    if (badges) {
      stats.push(
        { label: 'gold', value: badges.gold, accent: '#f1b600' },
        { label: 'silver', value: badges.silver, accent: '#9a9c9f' },
        { label: 'bronze', value: badges.bronze, accent: '#ab825f' },
      );
    }

    return {
      ...base,
      ok: true,
      days,
      profile: {
        handle: String(user.user_id),
        displayName: user.display_name,
        avatarUrl: user.profile_image,
        profileUrl: user.link,
        stats,
      },
    };
  } catch (err) {
    return { ...base, ok: false, days: [], error: (err as Error).message };
  }
}

/**
 * Page the activity timeline, newest first, stopping at the window edge.
 *
 * Capped hard: the quota is 300 calls a day per IP without a key, so a single
 * prolific user must not be able to spend it. Running out mid-window yields a
 * shorter history rather than an error — a slightly short grid beats a dead
 * row.
 */
async function collectTimeline(
  userId: number,
  fromDate: number,
  ctx: FetchContext,
  headers: Record<string, string>,
): Promise<SeTimelineItem[]> {
  const PAGE_SIZE = 100;
  const MAX_PAGES = 5;
  const all: SeTimelineItem[] = [];

  for (let page = 1; page <= MAX_PAGES; page++) {
    const url = withKey(
      `${API}/users/${userId}/timeline?site=${SITE}&fromdate=${fromDate}` +
        `&pagesize=${PAGE_SIZE}&page=${page}&filter=default`,
      ctx,
    );

    const body = await seCall<SeTimelineItem>(url, ctx, headers);
    all.push(...(body.items ?? []));

    if (!body.has_more) break;
    // Back off rather than burn the remaining budget on one user.
    if (typeof body.quota_remaining === 'number' && body.quota_remaining < 20) break;
  }

  return all;
}
