import Link from 'next/link';

/**
 * A 404 that offers the two things someone at a dead end actually wants: the
 * way back, and the most likely reason they are here — a mistyped profile
 * slug, which is the only URL shape on this site a person ever types by hand.
 */
export default function NotFound() {
  return (
    <main className="wrap" style={{ padding: '110px 24px 90px' }}>
      <div className="eyebrow">404</div>

      <h1
        className="display"
        style={{ fontSize: 'clamp(44px, 8vw, 92px)', marginTop: 18, maxWidth: 14 + 'ch' }}
      >
        Nothing here.
      </h1>

      <p className="dim" style={{ fontSize: 18, lineHeight: 1.6, marginTop: 24, maxWidth: '58ch' }}>
        If you were opening someone&rsquo;s profile, the link may be mistyped. A
        profile URL looks like{' '}
        <code className="mono" style={{ whiteSpace: 'nowrap' }}>
          /u/gh-torvalds+cf-tourist
        </code>{' '}
        &mdash; one <span className="mono">platform-handle</span> pair per
        source, joined with <span className="mono">+</span>.
      </p>

      <div style={{ display: 'flex', gap: 12, marginTop: 36, flexWrap: 'wrap' }}>
        <Link href="/" className="btn" style={{ textDecoration: 'none' }}>
          Build a streak
        </Link>
        <Link href="/compare" className="btn btn-ghost" style={{ textDecoration: 'none' }}>
          Leaderboard
        </Link>
      </div>
    </main>
  );
}
