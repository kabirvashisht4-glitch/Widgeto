'use client';

import { useCallback, useEffect, useState } from 'react';
import type { AttributedDay, PlatformId, PlatformResult, StreakSummary } from '@widgeto/core';
import WidgetCard from './WidgetCard';
import { PLATFORM_COLORS } from './ContributionGrid';

/**
 * The live console.
 *
 * The landing page *is* the onboarding flow: type the handles you already know,
 * get your real widget on screen before installing anything. Nothing to sign up
 * for, because every source here is public profile data keyed by username —
 * which is exactly why Widgeto can skip the OAuth wall its competitors need.
 */

interface Payload {
  summary: StreakSummary;
  heatmap: AttributedDay[];
  platforms: PlatformResult[];
}

const FIELDS: { id: PlatformId; label: string; hint: string; support: 'official' | 'unofficial' }[] = [
  { id: 'github', label: 'GitHub', hint: 'torvalds', support: 'official' },
  { id: 'codeforces', label: 'Codeforces', hint: 'tourist', support: 'official' },
  { id: 'leetcode', label: 'LeetCode', hint: 'lee215', support: 'unofficial' },
  { id: 'atcoder', label: 'AtCoder', hint: 'tourist', support: 'unofficial' },
];

const DEMO: Record<PlatformId, string> = {
  github: 'torvalds',
  codeforces: 'tourist',
  leetcode: 'lee215',
  atcoder: 'tourist',
};

export default function StreakStudio() {
  const [handles, setHandles] = useState<Record<string, string>>({});
  const [data, setData] = useState<Payload | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [timezone, setTimezone] = useState('UTC');

  // Resolved on the client so the streak is computed in the visitor's own day
  // boundary rather than the server's.
  useEffect(() => {
    setTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');
  }, []);

  const run = useCallback(
    async (source: Record<string, string>) => {
      const filled = Object.entries(source).filter(([, v]) => v.trim());
      if (filled.length === 0) {
        setError('Add at least one handle.');
        return;
      }
      setLoading(true);
      setError(null);
      try {
        const params = new URLSearchParams({ tz: timezone });
        for (const [k, v] of filled) params.set(k, v.trim());
        const res = await fetch(`/api/streak?${params}`);
        const body = await res.json();
        if (!res.ok) throw new Error(body.error ?? `request failed (${res.status})`);
        setData(body);
      } catch (err) {
        setError((err as Error).message);
      } finally {
        setLoading(false);
      }
    },
    [timezone],
  );

  const filledCount = Object.values(handles).filter((v) => v.trim()).length;

  return (
    <div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          run(handles);
        }}
        style={{ display: 'grid', gap: 12 }}
      >
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
            gap: 12,
          }}
        >
          {FIELDS.map((f) => (
            <label
              key={f.id}
              className="field"
              style={{ ['--accent' as string]: PLATFORM_COLORS[f.id] }}
            >
              <span
                style={{
                  width: 8,
                  height: 8,
                  borderRadius: 2,
                  background: PLATFORM_COLORS[f.id],
                  flexShrink: 0,
                }}
              />
              <input
                value={handles[f.id] ?? ''}
                onChange={(e) => setHandles((h) => ({ ...h, [f.id]: e.target.value }))}
                placeholder={f.hint}
                aria-label={`${f.label} handle`}
                spellCheck={false}
                autoComplete="off"
              />
              <span className="eyebrow" style={{ fontSize: 9 }}>
                {f.label}
              </span>
            </label>
          ))}
        </div>

        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <button className="btn" type="submit" disabled={loading || filledCount === 0}>
            {loading ? 'Merging…' : 'Build my streak'}
          </button>
          <button
            className="btn btn-ghost"
            type="button"
            disabled={loading}
            onClick={() => {
              setHandles(DEMO);
              run(DEMO);
            }}
          >
            Try a demo
          </button>
          <span className="mono faint" style={{ fontSize: 11 }}>
            no account · public profiles only · {timezone}
          </span>
        </div>
      </form>

      {error && (
        <div
          className="mono"
          style={{
            marginTop: 16,
            padding: '12px 14px',
            borderRadius: 12,
            fontSize: 12.5,
            color: 'var(--danger)',
            border: '1px solid color-mix(in srgb, var(--danger) 35%, transparent)',
            background: 'color-mix(in srgb, var(--danger) 8%, transparent)',
          }}
        >
          {error}
        </div>
      )}

      <div style={{ marginTop: 22 }}>
        {data ? (
          <WidgetCard summary={data.summary} heatmap={data.heatmap} platforms={data.platforms} />
        ) : (
          <Placeholder loading={loading} />
        )}
      </div>
    </div>
  );
}

/** An empty grid so the page has the product's shape before any data arrives. */
function Placeholder({ loading }: { loading: boolean }) {
  return (
    <div
      className="card"
      style={{
        padding: 26,
        minHeight: 260,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div style={{ textAlign: 'center' }}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(26, 9px)',
            gap: 3,
            marginBottom: 18,
            opacity: loading ? 0.55 : 0.22,
            transition: 'opacity 300ms ease',
          }}
        >
          {Array.from({ length: 26 * 5 }).map((_, i) => (
            <div
              key={i}
              style={{
                width: 9,
                height: 9,
                borderRadius: 2,
                background: '#1a1e26',
                animation: loading ? `pop 900ms ease ${(i % 26) * 24}ms infinite alternate` : undefined,
              }}
            />
          ))}
        </div>
        <div className="mono faint" style={{ fontSize: 12 }}>
          {loading ? 'talking to three APIs…' : 'your merged year shows up here'}
        </div>
      </div>
    </div>
  );
}
