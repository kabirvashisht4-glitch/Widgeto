/**
 * /u/gh-torvalds+cf-tourist — a shareable streak profile.
 *
 * There is no account behind this page: the handles in the URL *are* the
 * identity. That is what makes a Widgeto profile shareable at all — anyone can
 * open it, nobody has to sign up, and the person who owns the handles never
 * had to create anything.
 */
import type { Metadata } from 'next';
import Link from 'next/link';
import {
  aggregate,
  attributeHeatmap,
  CONNECTORS,
  decodeSlug,
  describeHandles,
  safeTimezone,
} from '@widgeto/core';
import type { PlatformId } from '@widgeto/core';
import ProfileView from '../../components/ProfileView';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Params = {
  params: Promise<{ slug: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export async function generateMetadata({ params }: Pick<Params, 'params'>): Promise<Metadata> {
  const { slug } = await params;
  const handles = decodeSlug(slug);
  const who = describeHandles(handles);
  const description = `The merged coding streak of ${who}, across every platform they code on.`;

  // The card image itself comes from opengraph-image.tsx alongside this file;
  // Next wires it up, so declaring `images` here would only fight it.
  return {
    title: who,
    description,
    openGraph: {
      type: 'profile',
      title: `${who} · Widgeto`,
      description,
      url: `/u/${slug}`,
    },
    twitter: {
      card: 'summary_large_image',
      title: `${who} · Widgeto`,
      description,
    },
  };
}

export default async function ProfilePage({ params, searchParams }: Params) {
  const { slug } = await params;
  const query = await searchParams;
  const handles = decodeSlug(slug);

  // A streak only means anything in one particular timezone, and the person
  // whose profile this is may be nowhere near the visitor. The share link
  // carries the owner's zone so everyone sees the same number they do; UTC is
  // the fallback when a link arrives without one.
  const tzParam = Array.isArray(query.tz) ? query.tz[0] : query.tz;
  const timezone = safeTimezone(tzParam ?? 'UTC');

  if (Object.keys(handles).length === 0) {
    return (
      <main className="wrap" style={{ padding: '90px 24px' }}>
        <h1 className="display" style={{ fontSize: 44 }}>That link doesn&rsquo;t name anyone.</h1>
        <p className="dim" style={{ marginTop: 16, fontSize: 17 }}>
          A profile URL looks like{' '}
          <code className="mono">/u/gh-torvalds+cf-tourist</code>.
        </p>
        <Link href="/" className="btn" style={{ display: 'inline-flex', alignItems: 'center', marginTop: 26, textDecoration: 'none' }}>
          Build your own
        </Link>
      </main>
    );
  }

  const activity = await aggregate(handles, {
    timezone,
    days: 365,
    githubToken: process.env.GITHUB_TOKEN,
  });

  const heatmap = attributeHeatmap(activity.platforms, 365, timezone);
  const live = activity.platforms.filter((p) => p.ok);

  return (
    <main>
      <nav className="wrap" style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '26px 24px' }}>
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">
            <rect x="1" y="12" width="8" height="8" rx="2" fill="#39d353" />
            <rect x="12" y="12" width="8" height="8" rx="2" fill="#ffa116" />
            <rect x="6.5" y="1.5" width="8" height="8" rx="2" fill="#4aa3e0" />
          </svg>
          <span style={{ fontWeight: 600 }}>Widgeto</span>
        </Link>
        <Link href="/" className="mono faint" style={{ marginLeft: 'auto', fontSize: 12, textDecoration: 'none' }}>
          build your own →
        </Link>
      </nav>

      <section className="wrap" style={{ paddingTop: 26, paddingBottom: 60 }}>
        <div className="eyebrow">
          {live.length} platform{live.length === 1 ? '' : 's'} merged
        </div>
        <h1 className="display" style={{ fontSize: 'clamp(38px, 6.5vw, 68px)', marginTop: 14 }}>
          {describeHandles(handles)}
        </h1>

        <div style={{ marginTop: 32 }}>
          <ProfileView
            summary={activity.summary}
            heatmap={heatmap}
            platforms={activity.platforms}
            slug={slug}
          />
        </div>

        {/* Per-platform detail — the reason to open someone's profile rather
            than just glance at their badge. */}
        <div
          style={{
            display: 'grid',
            gap: 14,
            gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
            marginTop: 22,
          }}
        >
          {live.map((p) => {
            const meta = CONNECTORS[p.platform as PlatformId];
            return (
              <div key={p.platform} className="card" style={{ padding: 22 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                  <span style={{ width: 9, height: 9, borderRadius: 2, background: meta.color }} />
                  <span style={{ fontWeight: 600, fontSize: 14.5 }}>{meta.name}</span>
                  <a
                    href={p.profile?.profileUrl}
                    target="_blank"
                    rel="noreferrer noopener"
                    className="mono faint"
                    style={{ marginLeft: 'auto', fontSize: 11.5 }}
                  >
                    {p.handle} ↗
                  </a>
                </div>
                <div style={{ display: 'grid', gap: 9, marginTop: 16 }}>
                  {p.profile?.stats.map((s) => (
                    <div key={s.label} style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
                      <span
                        className="mono"
                        style={{ fontSize: 16, fontWeight: 500, color: s.accent ?? 'var(--text)' }}
                      >
                        {s.value}
                      </span>
                      <span className="faint" style={{ fontSize: 12.5 }}>{s.label}</span>
                    </div>
                  ))}
                </div>
                <div className="mono faint" style={{ marginTop: 14, fontSize: 10.5 }}>
                  {p.days.length} active days · {p.precision === 'exact' ? 'exact days' : 'utc days'}
                </div>
              </div>
            );
          })}
        </div>
      </section>
    </main>
  );
}
