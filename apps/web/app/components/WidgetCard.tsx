'use client';

import type { AttributedDay, PlatformResult, StreakSummary } from '@widgeto/core';
import { PLATFORM_COLORS } from './ContributionGrid';
import ContributionGrid from './ContributionGrid';

/**
 * The widget face, at roughly the proportions of a large home-screen widget.
 * The site and the phone render the same payload, so what you see here is what
 * actually lands on the home screen.
 */

const STATUS_COPY = {
  safe: { label: 'done today', color: 'var(--github)' },
  'at-risk': { label: 'not yet today', color: 'var(--flame-hot)' },
  broken: { label: 'streak broken', color: 'var(--danger)' },
} as const;

export default function WidgetCard({
  summary,
  heatmap,
  platforms,
}: {
  summary: StreakSummary;
  heatmap: AttributedDay[];
  platforms: PlatformResult[];
}) {
  const status = STATUS_COPY[summary.status];
  const live = platforms.filter((p) => p.ok);
  const failed = platforms.filter((p) => !p.ok);

  return (
    <div className="card" style={{ padding: 26, overflow: 'hidden' }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
          gap: 20,
          flexWrap: 'wrap',
        }}
      >
        <div>
          <div className="eyebrow">unified streak</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginTop: 6 }}>
            <span
              className="mono"
              style={{
                fontSize: 76,
                fontWeight: 700,
                lineHeight: 1,
                letterSpacing: '-0.04em',
                background: 'linear-gradient(160deg, var(--flame-hot), var(--flame))',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              {summary.currentStreak}
            </span>
            <span className="dim" style={{ fontSize: 15 }}>
              day{summary.currentStreak === 1 ? '' : 's'}
            </span>
          </div>
          <div
            className="mono"
            style={{ marginTop: 8, fontSize: 12, color: status.color, display: 'flex', gap: 7, alignItems: 'center' }}
          >
            <span
              style={{
                width: 7,
                height: 7,
                borderRadius: 99,
                background: status.color,
                boxShadow: `0 0 10px ${status.color}`,
              }}
            />
            {status.label}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 26 }}>
          <Metric value={summary.longestStreak} label="longest" />
          <Metric value={summary.totalActiveDays} label="active days" />
          <Metric value={summary.totalContributions.toLocaleString()} label="total" />
        </div>
      </div>

      <div style={{ marginTop: 22 }}>
        <ContributionGrid days={heatmap} />
      </div>

      <hr className="rule" style={{ margin: '18px 0 16px' }} />

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {live.map((p) => (
          <div key={p.platform} style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            <span
              style={{
                width: 8,
                height: 8,
                borderRadius: 2,
                background: PLATFORM_COLORS[p.platform],
                flexShrink: 0,
              }}
            />
            <a
              href={p.profile?.profileUrl}
              target="_blank"
              rel="noreferrer noopener"
              className="mono"
              style={{ fontSize: 12.5, textDecoration: 'none', minWidth: 130 }}
            >
              {p.handle}
            </a>
            <span className="mono faint" style={{ fontSize: 11.5 }}>
              {p.profile?.stats
                .slice(0, 3)
                .map((s) => `${s.value} ${s.label}`)
                .join('  ·  ')}
            </span>
          </div>
        ))}

        {failed.map((p) => (
          <div key={p.platform} className="mono" style={{ fontSize: 11.5, color: 'var(--danger)' }}>
            {p.platform} · {p.handle} — {p.error}
          </div>
        ))}
      </div>

      <div className="mono faint" style={{ marginTop: 16, fontSize: 10.5 }}>
        days counted in {summary.timezone} · today is {summary.today}
      </div>
    </div>
  );
}

function Metric({ value, label }: { value: string | number; label: string }) {
  return (
    <div>
      <div className="mono" style={{ fontSize: 22, fontWeight: 500 }}>
        {value}
      </div>
      <div className="eyebrow" style={{ marginTop: 3 }}>
        {label}
      </div>
    </div>
  );
}
