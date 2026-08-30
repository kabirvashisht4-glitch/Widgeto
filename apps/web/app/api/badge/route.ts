/**
 * GET /api/badge?github=…&codeforces=…&style=card|flat
 *
 * An SVG your streak lives in, embeddable in a GitHub README. This is the
 * cheapest distribution this product has: the audience already decorates their
 * READMEs with stat cards, and every reader of that README sees a merged
 * streak no single-platform card can show.
 *
 * Rendered as SVG rather than a raster so it stays sharp, tiny, and needs no
 * image pipeline. No external fonts — GitHub's image proxy would not load them.
 */
import { NextRequest, NextResponse } from 'next/server';
import {
  aggregate,
  attributeHeatmap,
  normalizeHandle,
  PLATFORM_IDS,
  safeTimezone,
} from '@widgeto/core';
import type { AttributedDay, HandleMap, PlatformId } from '@widgeto/core';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/* The badge lands in READMEs on both light and dark GitHub, so it paints its
   own dark ground and stays legible either way. Colours and geometry match the
   site: hard corners, and hue reserved for platform identity. */
const HUE: Record<PlatformId, [number, number, number]> = {
  github: [63, 185, 80],
  codeforces: [88, 166, 255],
  leetcode: [255, 166, 87],
  atcoder: [208, 176, 112],
};
const EMPTY: [number, number, number] = [28, 28, 31];
const GROUND: [number, number, number] = [9, 9, 11];

const INK = '#fafafa';
const MUTED = '#8b8b95';
const OK = '#3fb950';
const BAD = '#ff7b72';

const FONT =
  "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif";
const MONO = "ui-monospace,SFMono-Regular,'SF Mono',Menlo,Consolas,monospace";

const rgb = (c: number[]) => `#${c.map((n) => Math.round(n).toString(16).padStart(2, '0')).join('')}`;

/** Same blend rule as the site and the widget, so all three agree. */
function cellColor(day: AttributedDay, peak: number): string {
  if (day.count <= 0) return rgb(EMPTY);

  let r = 0, g = 0, b = 0, w = 0;
  for (const [id, n] of Object.entries(day.byPlatform) as [PlatformId, number][]) {
    if (!n) continue;
    const weight = Math.sqrt(n);
    const hue = HUE[id];
    r += hue[0] * weight; g += hue[1] * weight; b += hue[2] * weight; w += weight;
  }
  if (w === 0) return rgb(EMPTY);

  const t = 0.25 + 0.75 * Math.min(1, Math.sqrt(day.count / peak));
  const blended = [r / w, g / w, b / w];
  return rgb(GROUND.map((base, i) => base + (blended[i] - base) * t));
}

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function svgResponse(svg: string, seconds: number) {
  return new NextResponse(svg, {
    headers: {
      'Content-Type': 'image/svg+xml; charset=utf-8',
      // GitHub proxies README images through camo, which caches on its own.
      // A short max-age keeps a streak from looking stale for a whole day.
      'Cache-Control': `public, max-age=${seconds}, s-maxage=${seconds}`,
    },
  });
}

function errorBadge(message: string) {
  const w = 20 + message.length * 6.6;
  return svgResponse(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="28" role="img" aria-label="${esc(message)}">
  <rect width="${w}" height="28" fill="#09090b" stroke="#3f3f46"/>
  <text x="10" y="18.5" font-family="${MONO}" font-size="11" fill="${BAD}">${esc(message)}</text>
</svg>`,
    60,
  );
}

export async function GET(req: NextRequest) {
  const params = req.nextUrl.searchParams;
  const timezone = safeTimezone(params.get('tz') ?? undefined);
  const style = params.get('style') === 'flat' ? 'flat' : 'card';

  const handles: HandleMap = {};
  for (const id of PLATFORM_IDS) {
    const raw = params.get(id);
    if (!raw) continue;
    const handle = normalizeHandle(raw);
    if (handle) handles[id as PlatformId] = handle;
  }
  if (Object.keys(handles).length === 0) return errorBadge('widgeto: add a handle');

  let activity;
  try {
    activity = await aggregate(handles, {
      timezone,
      days: style === 'flat' ? 60 : 182,
      githubToken: process.env.GITHUB_TOKEN,
      timeoutMs: 11_000,
    });
  } catch {
    return errorBadge('widgeto: upstream error');
  }

  if (!activity.platforms.some((p) => p.ok)) {
    return errorBadge('widgeto: no data');
  }

  const { summary } = activity;
  // The number is the page's ink, not a colour. Only a broken streak — which
  // genuinely means something — takes a hue.
  const accent = summary.status === 'broken' ? BAD : INK;

  if (style === 'flat') {
    const label = 'streak';
    const value = `${summary.currentStreak}d`;
    const lw = 20 + label.length * 7.4;
    const vw = 22 + value.length * 7.4;
    return svgResponse(
      `<svg xmlns="http://www.w3.org/2000/svg" width="${lw + vw}" height="28" role="img" aria-label="${label} ${value}">
  <rect x="0.75" y="0.75" width="${lw + vw - 1.5}" height="26.5" fill="#09090b" stroke="#3f3f46" stroke-width="1.5"/>
  <rect x="${lw}" y="0.75" width="1.5" height="26.5" fill="#3f3f46"/>
  <text x="10" y="18.5" font-family="${MONO}" font-size="10.5" letter-spacing="1.4" fill="${MUTED}">${label.toUpperCase()}</text>
  <text x="${lw + 11}" y="18.5" font-family="${MONO}" font-size="12" font-weight="700" fill="${accent}">${esc(value)}</text>
</svg>`,
      300,
    );
  }

  // ---- card ----
  const heatmap = attributeHeatmap(activity.platforms, 182, timezone);
  const peak = Math.max(1, ...heatmap.map((d) => d.count));

  const CELL = 8, GAP = 2.5, STEP = CELL + GAP;
  const pad = new Date(`${heatmap[0].date}T12:00:00Z`).getUTCDay();
  const cols = Math.ceil((heatmap.length + pad) / 7);

  const gridX = 168, gridY = 40;
  const W = gridX + cols * STEP + 18;
  const H = 148;

  const squares = heatmap
    .map((day, i) => {
      const idx = i + pad;
      return `<rect x="${(gridX + Math.floor(idx / 7) * STEP).toFixed(1)}" y="${(gridY + (idx % 7) * STEP).toFixed(1)}" width="${CELL}" height="${CELL}" fill="${cellColor(day, peak)}"/>`;
    })
    .join('');

  const live = activity.platforms.filter((p) => p.ok);
  const legend = live
    .map((p, i) => {
      const x = 22 + i * 15;
      return `<rect x="${x}" y="121" width="9" height="9" fill="${rgb(HUE[p.platform])}"><title>${esc(p.handle)} on ${p.platform}</title></rect>`;
    })
    .join('');

  const statusText =
    summary.status === 'safe' ? 'done today'
    : summary.status === 'at-risk' ? 'not yet today'
    : 'streak broken';

  const statusColor =
    summary.status === 'safe' ? OK : summary.status === 'broken' ? BAD : MUTED;

  return svgResponse(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Unified coding streak: ${summary.currentStreak} days across ${live.length} platforms">
  <rect x="0.75" y="0.75" width="${W - 1.5}" height="${H - 1.5}" fill="#09090b" stroke="#3f3f46" stroke-width="1.5"/>
  <text x="22" y="32" font-family="${MONO}" font-size="9" letter-spacing="2.2" fill="${MUTED}">UNIFIED STREAK</text>
  <text x="20" y="88" font-family="${MONO}" font-size="54" font-weight="700" letter-spacing="-2" fill="${accent}">${summary.currentStreak}</text>
  <text x="${24 + String(summary.currentStreak).length * 33}" y="88" font-family="${FONT}" font-size="13" fill="${MUTED}">days</text>
  <rect x="22" y="99" width="7" height="7" fill="${statusColor}"/>
  <text x="35" y="106" font-family="${MONO}" font-size="10.5" fill="${statusColor}">${statusText}</text>
  ${legend}
  <text x="${22 + live.length * 15 + 8}" y="129" font-family="${MONO}" font-size="9.5" fill="${MUTED}">${live.length} platform${live.length === 1 ? '' : 's'} · longest ${summary.longestStreak}d</text>
  ${squares}
  <text x="${gridX}" y="${gridY - 8}" font-family="${MONO}" font-size="8.5" letter-spacing="1.2" fill="${MUTED}">LAST 6 MONTHS · COLOUR = PLATFORM</text>
</svg>`,
    600,
  );
}
