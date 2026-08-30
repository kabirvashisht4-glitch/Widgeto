/**
 * The social card for a profile, as a PNG.
 *
 * The README badge is an SVG, which is right for a README and wrong here:
 * Twitter, Slack, Discord and Facebook all decline to render SVG previews, so
 * pointing og:image at it would produce no card at all. This renders the same
 * information through Satori into a real raster image.
 */
import { ImageResponse } from 'next/og';
import {
  aggregate,
  attributeHeatmap,
  decodeSlug,
  describeHandles,
  safeTimezone,
} from '@widgeto/core';
import type { AttributedDay, PlatformId } from '@widgeto/core';

export const runtime = 'nodejs';
export const alt = 'A unified coding streak across every connected platform';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

const HUE: Record<PlatformId, [number, number, number]> = {
  github: [57, 211, 83],
  codeforces: [74, 163, 224],
  leetcode: [255, 161, 22],
  atcoder: [176, 141, 79],
};
const EMPTY: [number, number, number] = [26, 30, 38];
const GROUND: [number, number, number] = [11, 13, 17];

const css = (c: number[]) => `rgb(${c.map(Math.round).join(',')})`;

/** The same blend rule as the site, the badge and the widget. */
function cellColor(day: AttributedDay, peak: number): string {
  if (day.count <= 0) return css(EMPTY);
  let r = 0, g = 0, b = 0, w = 0;
  for (const [id, n] of Object.entries(day.byPlatform) as [PlatformId, number][]) {
    if (!n) continue;
    const weight = Math.sqrt(n);
    const hue = HUE[id];
    r += hue[0] * weight; g += hue[1] * weight; b += hue[2] * weight; w += weight;
  }
  if (w === 0) return css(EMPTY);
  const t = 0.25 + 0.75 * Math.min(1, Math.sqrt(day.count / peak));
  return css(GROUND.map((base, i) => base + ([r / w, g / w, b / w][i] - base) * t));
}

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const handles = decodeSlug(slug);
  const who = describeHandles(handles);

  let streak = 0;
  let longest = 0;
  let cells: AttributedDay[] = [];
  let live: string[] = [];

  try {
    const activity = await aggregate(handles, {
      timezone: safeTimezone('UTC'),
      days: 182,
      githubToken: process.env.GITHUB_TOKEN,
      timeoutMs: 9000,
    });
    streak = activity.summary.currentStreak;
    longest = activity.summary.longestStreak;
    cells = attributeHeatmap(activity.platforms, 182, 'UTC');
    live = activity.platforms.filter((p) => p.ok).map((p) => p.platform);
  } catch {
    // A card that renders with zeroes still beats a broken preview.
  }

  const peak = Math.max(1, ...cells.map((d) => d.count));
  const columns: AttributedDay[][] = [];
  for (let i = 0; i < cells.length; i += 7) columns.push(cells.slice(i, i + 7));

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          background: '#0b0d11',
          padding: 64,
          color: '#e9ecf2',
          fontFamily: 'sans-serif',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', fontSize: 22, letterSpacing: 6, color: '#5a6373' }}>
            UNIFIED STREAK
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-end', marginTop: 12 }}>
            <div style={{ display: 'flex', fontSize: 150, fontWeight: 700, color: '#ffb43d', lineHeight: 1 }}>
              {streak}
            </div>
            <div style={{ display: 'flex', fontSize: 34, color: '#8c95a4', marginLeft: 18, marginBottom: 18 }}>
              days
            </div>
          </div>
          <div style={{ display: 'flex', fontSize: 30, color: '#8c95a4', marginTop: 14 }}>
            {who}
          </div>
        </div>

        {/* Six months of the merged grid, coloured by platform. */}
        <div style={{ display: 'flex', gap: 4 }}>
          {columns.map((col, i) => (
            <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {col.map((day) => (
                <div
                  key={day.date}
                  style={{
                    width: 34,
                    height: 34,
                    borderRadius: 7,
                    background: cellColor(day, peak),
                  }}
                />
              ))}
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', fontSize: 26, color: '#5a6373' }}>
          <div style={{ display: 'flex', gap: 10, marginRight: 20 }}>
            {live.map((p) => (
              <div
                key={p}
                style={{
                  width: 22,
                  height: 22,
                  borderRadius: 5,
                  background: css(HUE[p as PlatformId]),
                }}
              />
            ))}
          </div>
          {/* One expression, one text node: Satori treats each interpolation
              as a separate child and rejects multi-child divs. */}
          <div style={{ display: 'flex' }}>
            {`${live.length} platform${live.length === 1 ? '' : 's'} · longest ${longest}d · widgeto`}
          </div>
        </div>
      </div>
    ),
    size,
  );
}
