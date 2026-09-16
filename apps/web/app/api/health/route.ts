/**
 * GET /api/health
 *
 * A liveness probe for uptime monitors and deploy checks. It reports whether
 * the server is configured — specifically whether a GitHub token is present,
 * since without one the largest connector silently fails for every user and
 * nothing else in the system would tell you.
 *
 * It deliberately does not call upstream APIs: a health check that depends on
 * four third parties reports their outages as ours.
 */
import { NextResponse } from 'next/server';
import { PLATFORM_IDS } from '@widgeto/core';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  const githubToken = Boolean(process.env.GITHUB_TOKEN);

  return NextResponse.json(
    {
      status: githubToken ? 'ok' : 'degraded',
      // Named so a deploy that forgot the token says so out loud.
      checks: { githubToken },
      platforms: PLATFORM_IDS,
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    },
    {
      status: githubToken ? 200 : 503,
      headers: { 'Cache-Control': 'no-store' },
    },
  );
}
