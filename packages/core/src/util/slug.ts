/**
 * Profile slugs.
 *
 * A Widgeto profile has no account behind it — the handles *are* the identity.
 * So the URL carries them directly, which means a profile link can be shared,
 * bookmarked and rendered without anyone signing up for anything.
 *
 *   /u/gh-torvalds+cf-tourist+lc-lee215
 *
 * Split on the FIRST hyphen only, because handles legitimately contain
 * hyphens (`kabirvashisht4-glitch`). `+` is the separator precisely because no
 * platform here permits it in a username.
 */
import type { HandleMap, PlatformId } from '../types.ts';
import { normalizeHandle } from './handle.ts';

const TO_SHORT: Record<PlatformId, string> = {
  github: 'gh',
  codeforces: 'cf',
  leetcode: 'lc',
  atcoder: 'ac',
};

const TO_LONG = Object.fromEntries(
  Object.entries(TO_SHORT).map(([long, short]) => [short, long as PlatformId]),
) as Record<string, PlatformId>;

/** Stable ordering so the same handles always produce the same URL. */
const ORDER = Object.keys(TO_SHORT) as PlatformId[];

export function encodeSlug(handles: HandleMap): string {
  return ORDER.filter((id) => handles[id]?.trim())
    .map((id) => `${TO_SHORT[id]}-${handles[id]!.trim()}`)
    .join('+');
}

export function decodeSlug(slug: string): HandleMap {
  const handles: HandleMap = {};
  // A browser may hand back `%2B` or a space where a `+` was.
  for (const part of decodeURIComponent(slug).replace(/ /g, '+').split('+')) {
    const cut = part.indexOf('-');
    if (cut < 1) continue;

    const platform = TO_LONG[part.slice(0, cut).toLowerCase()];
    if (!platform) continue;

    const handle = normalizeHandle(part.slice(cut + 1));
    if (handle) handles[platform] = handle;
  }
  return handles;
}

/** Human-readable summary of a slug, for page titles and social cards. */
export function describeHandles(handles: HandleMap): string {
  const names = ORDER.filter((id) => handles[id]).map((id) => handles[id]!);
  if (names.length === 0) return 'nobody';
  if (names.length === 1) return names[0];
  return `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`;
}
