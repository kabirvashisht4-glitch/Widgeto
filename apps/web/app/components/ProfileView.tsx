'use client';

import { useEffect, useState } from 'react';
import type { AttributedDay, PlatformResult, StreakSummary } from '@widgeto/core';
import WidgetCard from './WidgetCard';

/**
 * A profile's widget plus the two things people actually want once they see
 * their own streak: the link, and the README snippet. The badge is the growth
 * loop — this audience already decorates READMEs with stat cards, and every
 * reader of that README sees a merged streak no single-platform card can show.
 */
export default function ProfileView({
  summary,
  heatmap,
  platforms,
  slug,
}: {
  summary: StreakSummary;
  heatmap: AttributedDay[];
  platforms: PlatformResult[];
  slug: string;
}) {
  // Resolved after mount, never during render. Reading window.location while
  // rendering would make the server and client disagree on the <img src> and
  // React would refuse to patch it up.
  const [origin, setOrigin] = useState('');
  useEffect(() => setOrigin(window.location.origin), []);

  const query = platforms
    .filter((p) => p.ok)
    .map((p) => `${p.platform}=${encodeURIComponent(p.handle)}`)
    .join('&');

  // The <img> stays relative so it is identical on both sides of hydration.
  // Only the copyable snippets need an absolute URL, and those can wait for
  // the browser to tell us what host we are actually on.
  const badgeSrc = `/api/badge?${query}`;
  const badgeUrl = `${origin}${badgeSrc}`;
  const profileUrl = `${origin}/u/${slug}?tz=${encodeURIComponent(summary.timezone)}`;
  const markdown = `[![Widgeto streak](${badgeUrl})](${profileUrl})`;

  return (
    <div style={{ display: 'grid', gap: 18 }}>
      <WidgetCard summary={summary} heatmap={heatmap} platforms={platforms} />

      <div className="card" style={{ padding: 22 }}>
        <div className="eyebrow">put it in your readme</div>
        <p className="dim" style={{ fontSize: 14, marginTop: 10, marginBottom: 16 }}>
          A live SVG of the streak above. It updates on its own.
        </p>

        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={badgeSrc}
          alt={`Unified coding streak: ${summary.currentStreak} days`}
          style={{ maxWidth: '100%', display: 'block', marginBottom: 16 }}
        />

        <div style={{ display: 'grid', gap: 10 }}>
          <CopyRow label="Markdown" value={markdown} />
          <CopyRow label="Share link" value={profileUrl} />
        </div>
      </div>
    </div>
  );
}

function CopyRow({ label, value }: { label: string; value: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // Clipboard is blocked in some embedded contexts; the text is selectable
      // anyway, so failing silently is better than an alarming error.
    }
  }

  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'stretch', flexWrap: 'wrap' }}>
      <div
        className="field"
        style={{ flex: 1, minWidth: 240, cursor: 'text', overflow: 'hidden' }}
      >
        <span className="eyebrow" style={{ fontSize: 9, flexShrink: 0 }}>{label}</span>
        <input readOnly value={value} onFocus={(e) => e.currentTarget.select()} />
      </div>
      <button className="btn btn-ghost" type="button" onClick={copy} style={{ minWidth: 92 }}>
        {copied ? 'Copied' : 'Copy'}
      </button>
    </div>
  );
}
