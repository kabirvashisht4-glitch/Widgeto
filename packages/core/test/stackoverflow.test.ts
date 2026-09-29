import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fetchStackOverflow } from '../src/connectors/stackoverflow.ts';
import type { FetchContext } from '../src/types.ts';

/**
 * Offline by construction. A test that calls the real Stack Exchange API fails
 * whenever somebody else's service has a bad minute, and this API in
 * particular answers 300 requests a day per IP — a suite that spends that
 * budget is a suite nobody can run twice.
 */

const USER = {
  user_id: 22656,
  display_name: 'Jon Skeet',
  reputation: 1_400_000,
  link: 'https://stackoverflow.com/users/22656/jon-skeet',
  badge_counts: { gold: 895, silver: 9322, bronze: 9362 },
};

/** Seconds since epoch for a UTC instant, which is what the API returns. */
const at = (iso: string) => Math.floor(Date.parse(iso) / 1000);

function stubFetch(
  routes: { user?: unknown; timeline?: unknown[]; status?: number },
): { impl: typeof fetch; calls: string[]; concurrent: boolean } {
  const calls: string[] = [];
  let inFlight = 0;
  let concurrent = false;

  const impl = (async (url: string | URL | Request) => {
    const href = String(url);
    calls.push(href);
    inFlight++;
    if (inFlight > 1) concurrent = true;
    await new Promise((r) => setTimeout(r, 1));
    inFlight--;

    const body = href.includes('/timeline')
      ? { items: routes.timeline ?? [], has_more: false, quota_remaining: 290 }
      : { items: routes.user ? [routes.user] : [], has_more: false, quota_remaining: 290 };

    return new Response(JSON.stringify(body), {
      status: routes.status ?? 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }) as unknown as typeof fetch;

  return { impl, calls, get concurrent() { return concurrent; } };
}

const ctx = (impl: typeof fetch): FetchContext => ({
  timezone: 'Asia/Kolkata',
  days: 30,
  fetchImpl: impl,
  timeoutMs: 5000,
});

test('a display name is refused, with an explanation of what to use instead', async () => {
  const stub = stubFetch({});
  const r = await fetchStackOverflow('jonskeet', ctx(stub.impl));

  assert.equal(r.ok, false);
  assert.match(r.error!, /numeric user id/);
  assert.match(r.error!, /22656/, 'shows where to find it');
  assert.equal(stub.calls.length, 0, 'refused before spending any quota');
});

test('buckets timeline events into local days', async () => {
  // 18:45 UTC on the 1st is already the 2nd in Kolkata (+05:30).
  const stub = stubFetch({
    user: USER,
    timeline: [
      { creation_date: at('2026-09-01T10:00:00Z'), timeline_type: 'answered' },
      { creation_date: at('2026-09-01T11:00:00Z'), timeline_type: 'commented' },
      { creation_date: at('2026-09-01T18:45:00Z'), timeline_type: 'answered' },
    ],
  });

  const r = await fetchStackOverflow('22656', {
    ...ctx(stub.impl),
    days: 3650, // wide window so the fixture dates fall inside it
  });

  assert.equal(r.ok, true);
  assert.equal(r.precision, 'exact', 'per-event timestamps allow true local days');

  const byDate = Object.fromEntries(r.days.map((d) => [d.date, d.count]));
  assert.equal(byDate['2026-09-01'], 2);
  assert.equal(byDate['2026-09-02'], 1, 'the late event lands on the next local day');
});

test('reads the profile into stats', async () => {
  const stub = stubFetch({ user: USER, timeline: [] });
  const r = await fetchStackOverflow('22656', ctx(stub.impl));

  assert.equal(r.ok, true);
  assert.equal(r.profile?.displayName, 'Jon Skeet');
  assert.equal(r.profile?.profileUrl, USER.link);

  const labels = r.profile!.stats.map((s) => s.label);
  assert.deepEqual(labels, ['reputation', 'gold', 'silver', 'bronze']);
  assert.equal(r.profile!.stats[0].value, '1,400,000', 'reputation is readable, not raw');
});

test('calls sequentially — concurrency is what trips the backoff', async () => {
  const stub = stubFetch({ user: USER, timeline: [] });
  await fetchStackOverflow('22656', ctx(stub.impl));

  assert.equal(stub.concurrent, false, 'never two in flight at once');
  assert.ok(stub.calls.length >= 2, 'profile and timeline were both fetched');
});

test('an unknown id fails as a value, not an exception', async () => {
  const stub = stubFetch({ user: undefined, timeline: [] });
  const r = await fetchStackOverflow('999999999', ctx(stub.impl));

  assert.equal(r.ok, false);
  assert.match(r.error!, /no Stack Overflow user/);
  assert.deepEqual(r.days, [], 'a failed platform still returns a usable shape');
});

test("surfaces the API's own error message rather than a bare status", async () => {
  // Stack Exchange explains itself in the body even on a 4xx; reading the
  // status alone turns "Violation of backoff parameter" into "400".
  const impl = (async () =>
    new Response(
      JSON.stringify({ error_message: 'Violation of backoff parameter', error_id: 502 }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    )) as unknown as typeof fetch;

  const r = await fetchStackOverflow('22656', ctx(impl));
  assert.equal(r.ok, false);
  assert.match(r.error!, /backoff/i);
});

test('the window excludes events older than the requested range', async () => {
  const stub = stubFetch({
    user: USER,
    timeline: [
      { creation_date: at('2000-01-01T10:00:00Z'), timeline_type: 'answered' },
    ],
  });

  const r = await fetchStackOverflow('22656', { ...ctx(stub.impl), days: 30 });
  assert.equal(r.ok, true);
  assert.deepEqual(r.days, [], 'ancient events do not leak into a 30-day window');
});
