import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  clientKey,
  rateLimit,
  rateLimitHeaders,
  resetRateLimits,
} from '../app/lib/rateLimit.ts';

test('allows up to the limit, then refuses', () => {
  resetRateLimits();
  for (let i = 1; i <= 3; i++) {
    assert.equal(rateLimit('a', { limit: 3 }).ok, true, `request ${i}`);
  }
  const refused = rateLimit('a', { limit: 3 });
  assert.equal(refused.ok, false);
  assert.equal(refused.remaining, 0);
  assert.ok(refused.retryAfter >= 1, 'a refusal says when to come back');
});

test('clients are counted separately', () => {
  resetRateLimits();
  rateLimit('a', { limit: 1 });
  assert.equal(rateLimit('a', { limit: 1 }).ok, false);
  assert.equal(rateLimit('b', { limit: 1 }).ok, true, 'b is unaffected by a');
});

test('the window reopens once it expires', async () => {
  resetRateLimits();
  assert.equal(rateLimit('a', { limit: 1, windowMs: 20 }).ok, true);
  assert.equal(rateLimit('a', { limit: 1, windowMs: 20 }).ok, false);
  await new Promise((r) => setTimeout(r, 30));
  assert.equal(rateLimit('a', { limit: 1, windowMs: 20 }).ok, true, 'new window');
});

test('remaining counts down and never goes negative', () => {
  resetRateLimits();
  assert.equal(rateLimit('a', { limit: 2 }).remaining, 1);
  assert.equal(rateLimit('a', { limit: 2 }).remaining, 0);
  assert.equal(rateLimit('a', { limit: 2 }).remaining, 0, 'floored at zero');
});

test('headers tell a client how to back off', () => {
  resetRateLimits();
  const ok = rateLimitHeaders(rateLimit('a', { limit: 2 }));
  assert.equal(ok['X-RateLimit-Limit'], '2');
  assert.equal(ok['X-RateLimit-Remaining'], '1');
  assert.ok(!('Retry-After' in ok), 'no Retry-After while still allowed');

  rateLimit('a', { limit: 2 });
  const refused = rateLimitHeaders(rateLimit('a', { limit: 2 }));
  assert.ok('Retry-After' in refused, 'a refusal must say when');
});

test('identifies the client from the first forwarded address', () => {
  // The first entry is the client; everything after it is a proxy.
  assert.equal(
    clientKey(new Headers({ 'x-forwarded-for': '203.0.113.7, 70.41.3.18' })),
    '203.0.113.7',
  );
  assert.equal(clientKey(new Headers({ 'x-real-ip': '198.51.100.4' })), '198.51.100.4');
  assert.equal(
    clientKey(new Headers()),
    'anonymous',
    'an unproxied deployment limits everyone together rather than nobody',
  );
});
