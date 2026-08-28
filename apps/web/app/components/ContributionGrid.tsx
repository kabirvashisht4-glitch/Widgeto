'use client';

import { useMemo, useState } from 'react';
import type { AttributedDay, PlatformId } from '@widgeto/core';

/**
 * The blended contribution grid — Widgeto's signature visual.
 *
 * A normal contribution grid has one colour and can only say "you did
 * something today". This one colours each square by *where* the work happened
 * and blends the colours on days you touched more than one platform, so a
 * merged year is legible at a glance: green stretches are GitHub weeks, orange
 * runs are grind sessions, and the muddy-gold squares are the days you did
 * both. That mixing is the whole argument for unifying, drawn rather than
 * explained.
 */

export const PLATFORM_COLORS: Record<PlatformId, string> = {
  github: '#39d353',
  codeforces: '#4aa3e0',
  leetcode: '#ffa116',
  atcoder: '#b08d4f',
};

const EMPTY = '#1a1e26';
const BG = '#0c0e12';

function hexToRgb(hex: string): [number, number, number] {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

const rgbToCss = ([r, g, b]: [number, number, number]) =>
  `rgb(${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)})`;

/** Weighted average of each contributing platform's colour. */
function blend(byPlatform: Partial<Record<PlatformId, number>>): [number, number, number] {
  let total = 0;
  let [r, g, b] = [0, 0, 0];
  for (const [id, count] of Object.entries(byPlatform) as [PlatformId, number][]) {
    if (!count) continue;
    // Square-root weighting so a 40-commit day does not completely erase the
    // colour of the two LeetCode problems solved alongside it.
    const w = Math.sqrt(count);
    const [pr, pg, pb] = hexToRgb(PLATFORM_COLORS[id]);
    r += pr * w;
    g += pg * w;
    b += pb * w;
    total += w;
  }
  if (total === 0) return hexToRgb(EMPTY);
  return [r / total, g / total, b / total];
}

/** Mix a colour toward the background to express intensity. */
function withIntensity(color: [number, number, number], ratio: number): string {
  // Floor at 0.25 so a one-commit day is still visible, not a smudge.
  const t = 0.25 + 0.75 * Math.min(1, Math.sqrt(ratio));
  const bg = hexToRgb(BG);
  return rgbToCss([
    bg[0] + (color[0] - bg[0]) * t,
    bg[1] + (color[1] - bg[1]) * t,
    bg[2] + (color[2] - bg[2]) * t,
  ]);
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

interface Props {
  days: AttributedDay[];
  cell?: number;
  gap?: number;
  animate?: boolean;
}

export default function ContributionGrid({ days, cell = 11, gap = 3, animate = true }: Props) {
  const [hover, setHover] = useState<AttributedDay | null>(null);

  const { columns, peak, monthLabels } = useMemo(() => {
    if (days.length === 0) return { columns: [], peak: 1, monthLabels: [] };

    // Pad the first column so weeks line up on Sunday, like GitHub's grid.
    const firstDow = new Date(`${days[0].date}T12:00:00Z`).getUTCDay();
    const padded: (AttributedDay | null)[] = [...Array(firstDow).fill(null), ...days];

    const cols: (AttributedDay | null)[][] = [];
    for (let i = 0; i < padded.length; i += 7) cols.push(padded.slice(i, i + 7));

    const labels: { x: number; text: string }[] = [];
    let lastMonth = -1;
    cols.forEach((col, i) => {
      const first = col.find(Boolean);
      if (!first) return;
      const month = Number(first.date.slice(5, 7)) - 1;
      if (month !== lastMonth) {
        lastMonth = month;
        labels.push({ x: i * (cell + gap), text: MONTHS[month] });
      }
    });

    return {
      columns: cols,
      peak: Math.max(1, ...days.map((d) => d.count)),
      monthLabels: labels,
    };
  }, [days, cell, gap]);

  if (columns.length === 0) return null;

  const width = columns.length * (cell + gap);
  const height = 7 * (cell + gap) + 18;

  return (
    <div style={{ position: 'relative' }}>
      <div className="grid-scroll">
        <svg width={width} height={height} role="img" aria-label="Merged contribution activity">
          {monthLabels.map((m, i) => (
            <text
              key={i}
              x={m.x}
              y={10}
              fill="var(--text-faint)"
              fontSize={9}
              fontFamily="var(--font-mono)"
            >
              {m.text}
            </text>
          ))}
          {columns.map((col, ci) =>
            col.map((day, ri) => {
              if (!day) return null;
              const fill =
                day.count > 0 ? withIntensity(blend(day.byPlatform), day.count / peak) : EMPTY;
              return (
                <rect
                  key={day.date}
                  className={animate ? 'cell' : undefined}
                  x={ci * (cell + gap)}
                  y={ri * (cell + gap) + 18}
                  width={cell}
                  height={cell}
                  rx={2.5}
                  fill={fill}
                  style={animate ? { animationDelay: `${Math.min(ci * 7, 900)}ms` } : undefined}
                  onMouseEnter={() => setHover(day)}
                  onMouseLeave={() => setHover(null)}
                >
                  <title>{`${day.date}: ${day.count} contribution${day.count === 1 ? '' : 's'}`}</title>
                </rect>
              );
            }),
          )}
        </svg>
      </div>

      <div
        className="mono"
        style={{
          marginTop: 10,
          fontSize: 11,
          color: 'var(--text-dim)',
          minHeight: 18,
        }}
      >
        {hover ? (
          <>
            <span style={{ color: 'var(--text)' }}>{hover.count}</span> on {hover.date}
            {Object.entries(hover.byPlatform).length > 0 && (
              <span className="faint">
                {' — '}
                {(Object.entries(hover.byPlatform) as [PlatformId, number][])
                  .map(([id, n]) => `${id} ${n}`)
                  .join(' · ')}
              </span>
            )}
          </>
        ) : (
          <span className="faint">hover a square for the day&rsquo;s breakdown</span>
        )}
      </div>
    </div>
  );
}
