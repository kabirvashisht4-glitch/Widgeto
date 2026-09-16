/**
 * Per-client rate limiting.
 *
 * Widgeto's endpoints are public and unauthenticated by design — the whole
 * point is that a handle is all you need. That also means anyone can point a
 * loop at them, and every request that misses the cache costs calls to four
 * upstreams, two of which are community services we are guests on. Getting
 * those blocked would break the product for every user at once, so the limit
 * exists to protect the upstreams as much as the server.
 *
 * A fixed window in memory: correct for one instance, and the right shape to
 * swap for Redis or Workers KV when there is more than one. Deliberately not a
 * dependency — the whole thing is thirty lines.
 */

export interface RateLimitResult {
  ok: boolean;
  limit: number;
  remaining: number;
  /** Unix seconds when the current window resets. */
  reset: number;
  retryAfter: number;
}

interface Window {
  count: number;
  resetAt: number;
}

const buckets = new Map<string, Window>();
const MAX_KEYS = 10_000;

/**
 * Identify the caller.
 *
 * Behind Vercel, Netlify or any sane proxy the real address is in
 * `x-forwarded-for`; its first entry is the client and the rest are proxies.
 * Falling back to a shared constant means an unproxied deployment rate-limits
 * everyone together, which is a blunt but safe failure.
 */
export function clientKey(headers: Headers): string {
  const forwarded = headers.get('x-forwarded-for');
  if (forwarded) return forwarded.split(',')[0]!.trim();
  return headers.get('x-real-ip') ?? headers.get('cf-connecting-ip') ?? 'anonymous';
}

export function rateLimit(
  key: string,
  { limit = 30, windowMs = 60_000 }: { limit?: number; windowMs?: number } = {},
): RateLimitResult {
  const now = Date.now();
  let bucket = buckets.get(key);

  if (!bucket || bucket.resetAt <= now) {
    bucket = { count: 0, resetAt: now + windowMs };
    // Evict the oldest key rather than growing without bound; a Map preserves
    // insertion order, so the first key is the least recently created.
    if (buckets.size >= MAX_KEYS) {
      const oldest = buckets.keys().next().value;
      if (oldest !== undefined) buckets.delete(oldest);
    }
    buckets.set(key, bucket);
  }

  bucket.count++;

  const reset = Math.ceil(bucket.resetAt / 1000);
  return {
    ok: bucket.count <= limit,
    limit,
    remaining: Math.max(0, limit - bucket.count),
    reset,
    retryAfter: Math.max(1, Math.ceil((bucket.resetAt - now) / 1000)),
  };
}

/** Standard headers, so a client can back off without guessing. */
export function rateLimitHeaders(r: RateLimitResult): Record<string, string> {
  return {
    'X-RateLimit-Limit': String(r.limit),
    'X-RateLimit-Remaining': String(r.remaining),
    'X-RateLimit-Reset': String(r.reset),
    ...(r.ok ? {} : { 'Retry-After': String(r.retryAfter) }),
  };
}

/** Test seam: windows are process-global, so tests must be able to clear them. */
export function resetRateLimits(): void {
  buckets.clear();
}
