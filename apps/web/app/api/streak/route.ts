/**
 * GET /api/streak?github=…&codeforces=…&leetcode=…&tz=Asia/Kolkata
 *
 * The single endpoint the site and the phone widget both call. It exists so
 * that the GitHub token stays on the server and so that upstream APIs see one
 * polite caller instead of one per widget refresh.
 */
import { NextRequest, NextResponse } from 'next/server';
import { aggregate, attributeHeatmap, normalizeHandle, PLATFORM_IDS, safeTimezone } from '@widgeto/core';
import type { HandleMap, PlatformId, UnifiedActivity } from '@widgeto/core';

export const runtime = 'nodejs';
// Never statically rendered — the answer depends entirely on query params.
export const dynamic = 'force-dynamic';

/**
 * Two of the three upstreams are rate-limited and one is a guest endpoint we
 * must not hammer, so identical requests inside the TTL are served from memory.
 * A real deployment swaps this for Redis or Workers KV; the interface is the
 * same and the reasoning does not change.
 */
const TTL_MS = 10 * 60 * 1000;
/** A result with a failed connector is cached briefly, so a transient upstream
 *  blip cannot freeze a broken row in place for a full ten minutes. */
const PARTIAL_TTL_MS = 2 * 60 * 1000;
const MAX_ENTRIES = 500;
const cache = new Map<string, { at: number; ttl: number; body: unknown }>();

function readCache(key: string) {
  const hit = cache.get(key);
  if (!hit) return null;
  if (Date.now() - hit.at > hit.ttl) {
    cache.delete(key);
    return null;
  }
  // Refresh insertion order so the map behaves as an LRU.
  cache.delete(key);
  cache.set(key, hit);
  return hit.body;
}

function writeCache(key: string, body: unknown, ttl: number) {
  cache.set(key, { at: Date.now(), ttl, body });
  while (cache.size > MAX_ENTRIES) cache.delete(cache.keys().next().value as string);
}

export async function GET(req: NextRequest) {
  const params = req.nextUrl.searchParams;
  const timezone = safeTimezone(params.get('tz') ?? undefined);
  const days = Math.min(Math.max(Number(params.get('days') ?? 365), 7), 365);

  const handles: HandleMap = {};
  for (const id of PLATFORM_IDS) {
    const raw = params.get(id)?.trim();
    if (!raw) continue;
    // Accepts a bare handle, an @handle, or a pasted profile URL — people
    // paste the page they already have open far more often than they type a
    // bare username.
    const handle = normalizeHandle(raw);
    if (!handle) {
      return NextResponse.json(
        { error: `Couldn't read a ${id} username from "${raw}".` },
        { status: 400 },
      );
    }
    handles[id as PlatformId] = handle;
  }

  if (Object.keys(handles).length === 0) {
    return NextResponse.json({ error: 'add at least one handle' }, { status: 400 });
  }

  const key = `${timezone}|${days}|${PLATFORM_IDS.map((id) => handles[id] ?? '').join('|')}`;
  const cached = readCache(key);
  if (cached) {
    return NextResponse.json(cached, {
      headers: { 'x-widgeto-cache': 'hit', 'Access-Control-Allow-Origin': '*' },
    });
  }

  let activity: UnifiedActivity;
  try {
    activity = await aggregate(handles, {
      timezone,
      days,
      githubToken: process.env.GITHUB_TOKEN,
      timeoutMs: 12_000,
    });
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 502 });
  }

  const body = {
    summary: activity.summary,
    heatmap: attributeHeatmap(activity.platforms, days, timezone),
    platforms: activity.platforms,
  };

  // Only cache a result that actually carries data; caching a total failure
  // would lock the user out of a retry for ten minutes.
  const anyOk = activity.platforms.some((p) => p.ok);
  const allOk = activity.platforms.every((p) => p.ok);
  if (anyOk) writeCache(key, body, allOk ? TTL_MS : PARTIAL_TTL_MS);

  return NextResponse.json(body, {
    headers: {
      'x-widgeto-cache': 'miss',
      // Read-only public data keyed by public handles — there is nothing here
      // to protect with an origin check, and opening it lets the Flutter web
      // build (and anyone else) read it directly.
      'Access-Control-Allow-Origin': '*',
      // Let the CDN and the widget reuse this too.
      'Cache-Control': 'public, max-age=300, stale-while-revalidate=1800',
    },
  });
}
