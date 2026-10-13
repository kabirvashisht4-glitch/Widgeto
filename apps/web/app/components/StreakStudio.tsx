
'use client';

import { useCallback, useEffect, useState } from 'react';
import type { AttributedDay, PlatformId, PlatformResult, StreakSummary } from '@widgeto/core';
import WidgetCard from './WidgetCard';
import { PLATFORM_COLORS } from './ContributionGrid';

interface Payload {
  summary: StreakSummary;
  heatmap: AttributedDay[];
  platforms: PlatformResult[];
}

const FIELDS: {
  id: PlatformId;
  label: string;
  hint: string;
  support: 'official' | 'unofficial';
}[] = [
  { id: 'github', label: 'GitHub', hint: 'torvalds', support: 'official' },
  { id: 'codeforces', label: 'Codeforces', hint: 'tourist', support: 'official' },
  { id: 'leetcode', label: 'LeetCode', hint: 'lee215', support: 'unofficial' },
  { id: 'atcoder', label: 'AtCoder', hint: 'tourist', support: 'unofficial' },
  { id: 'stackoverflow', label: 'Stack Overflow', hint: '22656', support: 'official' },
];

const DEMO: Record<PlatformId, string> = {
  github: 'torvalds',
  codeforces: 'tourist',
  leetcode: 'lee215',
  atcoder: 'tourist',
  stackoverflow: '22656',
};

export default function StreakStudio() {
  const [handles, setHandles] = useState<Record<string, string>>({});
  const [data, setData] = useState<Payload | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [timezone, setTimezone] = useState('UTC');

  useEffect(() => {
    setTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');
  }, []);

  const run = useCallback(
    async (source: Record<string, string>) => {
      const filled = Object.entries(source).filter(([, value]) => value.trim());

      if (filled.length === 0) {
        setError('Add at least one handle.');
        return;
      }

      setLoading(true);
      setError(null);

      try {
        const params = new URLSearchParams({ tz: timezone });

        for (const [key, value] of filled) {
          params.set(key, value.trim());
        }

        const res = await fetch(`/api/streak?${params}`);
        const body = await res.json();

        if (!res.ok) {
          throw new Error(body.error ?? `request failed (${res.status})`);
        }

        setData(body);
      } catch (err) {
        setError((err as Error).message);
      } finally {
        setLoading(false);
      }
    },
    [timezone],
  );

  const filledCount = Object.values(handles).filter((value) => value.trim()).length;

  return (
    <div>
      <form
        onSubmit={(event) => {
          event.preventDefault();
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
          {FIELDS.map((field) => (
            <label
              key={field.id}
              className="field"
              style={{ ['--accent' as string]: PLATFORM_COLORS[field.id] }}
            >
              <span
                aria-hidden="true"
                style={{
                  width: 10,
                  height: 10,
                  background: PLATFORM_COLORS[field.id],
                  flexShrink: 0,
                }}
              />
              <input
                value={handles[field.id] ?? ''}
                onChange={(event) =>
                  setHandles((current) => ({
                    ...current,
                    [field.id]: event.target.value,
                  }))
                }
                placeholder={field.hint}
                aria-label={`${field.label} handle`}
                spellCheck={false}
                autoComplete="off"
              />
              <span className="eyebrow" style={{ fontSize: 9 }}>
                {field.label}
              </span>
            </label>
          ))}
        </div>

        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <button
            className="btn"
            type="submit"
            disabled={loading || filledCount === 0}
            aria-busy={loading}
          >
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

      <p className="sr-only" role="status" aria-live="polite">
        {loading
          ? 'Merging your platforms…'
          : error
            ? `Error: ${error}`
            : data
              ? `Your unified streak is ${data.summary.currentStreak} days, ${data.summary.status.replace('-', ' ')}.`
              : ''}
      </p>

      {error && (
        <div
          className="mono"
          style={{
            marginTop: 16,
            padding: '12px 14px',
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
          <WidgetCard
            summary={data.summary}
            heatmap={data.heatmap}
            platforms={data.platforms}
          />
        ) : (
          <Placeholder loading={loading} />
        )}
      </div>
    </div>
  );
}

function Placeholder({ loading }: { loading: boolean }) {
  return (
    <div
      className="card streak-placeholder"
      aria-busy={loading}
      aria-label={loading ? 'Loading your unified streak' : 'Your streak preview'}
    >
      <div className="streak-placeholder-header" aria-hidden="true">
        <div>
          <div className="eyebrow">unified streak</div>
          <div className="streak-skeleton streak-skeleton-number" />
          <div className="streak-skeleton streak-skeleton-status" />
        </div>

        <div className="streak-placeholder-metrics">
          {[64, 76, 52].map((width, index) => (
            <div key={index}>
              <div
                className="streak-skeleton"
                style={{ width, height: 24 }}
              />
              <div
                className="streak-skeleton"
                style={{ width, height: 9, marginTop: 8 }}
              />
            </div>
          ))}
        </div>
      </div>

      <div className="streak-placeholder-grid" aria-hidden="true">
        {Array.from({ length: 130 }, (_, index) => (
          <div
            key={index}
            className="streak-skeleton streak-skeleton-cell"
            style={{ animationDelay: `${(index % 26) * 12}ms` }}
          />
        ))}
      </div>

      <hr className="rule" style={{ margin: '18px 0 16px' }} />

      <div className="streak-placeholder-platforms" aria-hidden="true">
        {FIELDS.map((field) => (
          <div className="streak-placeholder-platform" key={field.id}>
            <div
              className="streak-skeleton"
              style={{ width: 8, height: 8, flexShrink: 0 }}
            />
            <div
              className="streak-skeleton"
              style={{ width: 130, height: 12 }}
            />
            <div
              className="streak-skeleton streak-platform-detail"
              style={{ width: 160, height: 10 }}
            />
          </div>
        ))}
      </div>

      <div className="mono faint streak-placeholder-footer">
        {loading ? 'merging platform data…' : 'your merged year shows up here'}
      </div>
    </div>
  );
}
