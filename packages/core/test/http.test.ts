import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from '../src/util/http.ts';

/**
 * These messages are not developer logs — they are rendered on a widget and in
 * a row of the profile page, so they have to say what went wrong and whether
 * waiting will help.
 */

function respondWith(status: number, headers: Record<string, string> = {}): typeof fetch {
  return (async () => new Response('', { status, headers })) as unknown as typeof fetch;
}

const opts = { retries: 0, timeoutMs: 1000 };

test('a rate limit names the service and says to wait', async () => {
  await assert.rejects(
    request('https://api.stackexchange.com/2.3/users/1', {
      ...opts,
      fetchImpl: respondWith(429),
    }),
    (err: Error) => {
      assert.match(err.message, /api\.stackexchange\.com/, 'names who is refusing');
      assert.match(err.message, /rate limiting/);
      assert.doesNotMatch(err.message, /^upstream returned/);
      return true;
    },
  );
});

test('Retry-After is used when the service provides it', async () => {
  await assert.rejects(
    request('https://codeforces.com/api/user.info', {
      ...opts,
      fetchImpl: respondWith(429, { 'Retry-After': '42' }),
    }),
    (err: Error) => {
      assert.match(err.message, /about 42s/, 'a precise answer beats "shortly"');
      return true;
    },
  );
});

test('an outage reads differently from a rate limit', async () => {
  await assert.rejects(
    request('https://leetcode.com/graphql', { ...opts, fetchImpl: respondWith(503) }),
    (err: Error) => {
      assert.match(err.message, /unavailable/);
      assert.doesNotMatch(err.message, /rate limiting/, 'these need different reactions');
      return true;
    },
  );
});

test('an unexpected server error still names the host and the status', async () => {
  await assert.rejects(
    request('https://api.github.com/graphql', { ...opts, fetchImpl: respondWith(500) }),
    (err: Error) => {
      assert.match(err.message, /api\.github\.com/);
      assert.match(err.message, /500/);
      return true;
    },
  );
});

test('www is trimmed so the name reads as the service, not the URL', async () => {
  await assert.rejects(
    request('https://www.codechef.com/users/x', { ...opts, fetchImpl: respondWith(503) }),
    (err: Error) => {
      assert.match(err.message, /^codechef\.com/);
      return true;
    },
  );
});

test('a successful response is returned untouched', async () => {
  const res = await request('https://example.com/ok', {
    ...opts,
    fetchImpl: (async () => new Response('{"a":1}', { status: 200 })) as unknown as typeof fetch,
  });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { a: 1 });
});

test('retries a rate limit before giving up', async () => {
  let calls = 0;
  const flaky = (async () => {
    calls++;
    return new Response('', { status: calls < 3 ? 429 : 200 });
  }) as unknown as typeof fetch;

  const res = await request('https://example.com/flaky', {
    retries: 3,
    timeoutMs: 1000,
    fetchImpl: flaky,
  });

  assert.equal(res.status, 200);
  assert.equal(calls, 3, 'gave the service a chance to recover');
});
