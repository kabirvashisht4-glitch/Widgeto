/**
 * GitHub connector — the well-behaved one.
 *
 * GitHub is the only source here with a first-class, officially supported
 * contribution calendar, so it needs no scraping and no guessing. It does
 * require a token even to read a *public* calendar: the GraphQL API rejects
 * anonymous requests entirely. Widgeto uses a server-side token for handle-only
 * users, and the user's own OAuth token when they connect their account (which
 * additionally unlocks private contributions).
 */
import type { DayCount, FetchContext, PlatformResult } from '../types.ts';
import { ConnectorError, postJson } from '../util/http.ts';
import { addDays, today } from '../util/time.ts';

const ENDPOINT = 'https://api.github.com/graphql';

const QUERY = `
query($login: String!, $from: DateTime!, $to: DateTime!) {
  user(login: $login) {
    login
    name
    avatarUrl
    url
    followers { totalCount }
    repositories(first: 100, ownerAffiliations: OWNER, isFork: false,
                 orderBy: { field: STARGAZERS, direction: DESC }) {
      nodes { stargazerCount }
    }
    contributionsCollection(from: $from, to: $to) {
      totalPullRequestContributions
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount } }
      }
    }
  }
}`;

interface GraphQLReply {
  data?: {
    user: {
      login: string;
      name: string | null;
      avatarUrl: string;
      url: string;
      followers: { totalCount: number };
      repositories: { nodes: { stargazerCount: number }[] };
      contributionsCollection: {
        totalPullRequestContributions: number;
        contributionCalendar: {
          totalContributions: number;
          weeks: { contributionDays: { date: string; contributionCount: number }[] }[];
        };
      };
    } | null;
  };
  errors?: { message: string; type?: string }[];
}

export async function fetchGitHub(handle: string, ctx: FetchContext): Promise<PlatformResult> {
  const base = {
    platform: 'github' as const,
    handle,
    fetchedAt: new Date().toISOString(),
    // The calendar is a UTC grid; GitHub itself has no per-event timestamps here.
    precision: 'utc-day' as const,
  };

  try {
    if (!ctx.githubToken) {
      throw new ConnectorError('no GitHub token configured (GraphQL requires auth even for public data)');
    }

    // contributionsCollection accepts at most a one-year span.
    const end = today(ctx.timezone);
    const start = addDays(end, -Math.min(ctx.days, 365) + 1);

    const reply = await postJson<GraphQLReply>(
      ENDPOINT,
      { query: QUERY, variables: { login: handle, from: `${start}T00:00:00Z`, to: `${end}T23:59:59Z` } },
      {
        headers: {
          Authorization: `Bearer ${ctx.githubToken}`,
          'User-Agent': 'Widgeto',
        },
        fetchImpl: ctx.fetchImpl,
        timeoutMs: ctx.timeoutMs,
      },
    );

    if (reply.errors?.length) {
      throw new ConnectorError(reply.errors.map((e) => e.message).join('; '));
    }
    const user = reply.data?.user;
    if (!user) throw new ConnectorError(`no GitHub user named "${handle}"`);

    const cal = user.contributionsCollection.contributionCalendar;
    const days: DayCount[] = [];
    for (const week of cal.weeks) {
      for (const day of week.contributionDays) {
        if (day.contributionCount > 0) days.push({ date: day.date, count: day.contributionCount });
      }
    }
    days.sort((a, b) => a.date.localeCompare(b.date));

    const stars = user.repositories.nodes.reduce((sum, r) => sum + r.stargazerCount, 0);

    return {
      ...base,
      ok: true,
      days,
      profile: {
        handle: user.login,
        displayName: user.name ?? user.login,
        avatarUrl: user.avatarUrl,
        profileUrl: user.url,
        stats: [
          { label: 'contributions', value: cal.totalContributions },
          { label: 'PRs opened', value: user.contributionsCollection.totalPullRequestContributions },
          { label: 'stars', value: stars },
          { label: 'followers', value: user.followers.totalCount },
        ],
      },
    };
  } catch (err) {
    return { ...base, ok: false, days: [], error: (err as Error).message };
  }
}
