/**
 * Fan out to every configured connector, fold the results into one answer.
 */
import { CONNECTORS } from './connectors/index.ts';
import { buildHeatmap, computeStreak, mergeDays } from './streak.ts';
import type { FetchContext, HandleMap, PlatformId, PlatformResult, UnifiedActivity } from './types.ts';
import { safeTimezone } from './util/time.ts';

export interface AggregateOptions extends Partial<FetchContext> {
  now?: number;
}

/**
 * Connectors run concurrently and independently. One platform being down,
 * slow, or rate-limited must never block or fail the others — the widget is
 * expected to render *something* every single time it is asked.
 */
export async function aggregate(
  handles: HandleMap,
  options: AggregateOptions = {},
): Promise<UnifiedActivity> {
  const ctx: FetchContext = {
    timezone: safeTimezone(options.timezone),
    days: options.days ?? 365,
    githubToken: options.githubToken,
    fetchImpl: options.fetchImpl,
    timeoutMs: options.timeoutMs ?? 12_000,
  };

  const requested = (Object.entries(handles) as [PlatformId, string | undefined][])
    .filter(([id, handle]) => Boolean(handle) && id in CONNECTORS);

  const platforms: PlatformResult[] = await Promise.all(
    requested.map(([id, handle]) => CONNECTORS[id].fetch(handle!.trim(), ctx)),
  );

  const merged = mergeDays(platforms.filter((p) => p.ok).map((p) => p.days));

  return {
    summary: computeStreak(merged, { timezone: ctx.timezone, now: options.now }),
    heatmap: buildHeatmap(merged, ctx.days, ctx.timezone, options.now ?? Date.now()),
    platforms,
  };
}
