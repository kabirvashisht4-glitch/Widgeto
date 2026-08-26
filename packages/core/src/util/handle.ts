/**
 * Handle normalisation.
 *
 * People do not type bare usernames — they paste the profile URL they already
 * have open, or copy a handle with an `@` on the front. Rejecting those as
 * invalid is technically correct and practically hostile, so anything that
 * unambiguously identifies a user is accepted and reduced to the handle.
 */
import type { PlatformId } from '../types.ts';

/** Path segments that are routing, not usernames. */
const SKIP = new Set(['u', 'profile', 'user', 'users', 'account']);

/** GitHub caps at 39 chars; the others are shorter. Shared upper bound. */
const VALID = /^[A-Za-z0-9_.-]{1,39}$/;

/**
 * Reduce user input to a bare handle, or `null` if it cannot be one.
 *
 * Accepts: `torvalds`, `@torvalds`, `github.com/torvalds`,
 * `https://leetcode.com/u/lee215/`, `https://codeforces.com/profile/tourist?x=1`
 */
export function normalizeHandle(raw: string): string | null {
  let value = raw.trim();
  if (!value) return null;

  // Drop a query string or fragment before anything else.
  value = value.split(/[?#]/)[0];

  if (value.includes('/')) {
    value = value.replace(/^[a-z]+:\/\//i, '');
    const segments = value.split('/').filter(Boolean);
    // Drop the host, then any routing segments, and take what is left first.
    if (segments.length && segments[0].includes('.')) segments.shift();
    while (segments.length && SKIP.has(segments[0].toLowerCase())) segments.shift();
    value = segments[0] ?? '';
  }

  value = value.replace(/^@/, '');

  return VALID.test(value) ? value : null;
}

/** Convenience for a whole handle map; drops entries that cannot be salvaged. */
export function normalizeHandles(
  input: Partial<Record<PlatformId, string>>,
): { handles: Partial<Record<PlatformId, string>>; rejected: PlatformId[] } {
  const handles: Partial<Record<PlatformId, string>> = {};
  const rejected: PlatformId[] = [];

  for (const [id, raw] of Object.entries(input) as [PlatformId, string | undefined][]) {
    if (!raw?.trim()) continue;
    const clean = normalizeHandle(raw);
    if (clean) handles[id] = clean;
    else rejected.push(id);
  }
  return { handles, rejected };
}
