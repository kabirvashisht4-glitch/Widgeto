import type { Metadata } from 'next';
import Link from 'next/link';
import Leaderboard from '../components/Leaderboard';

export const metadata: Metadata = {
  title: 'Leaderboard — Widgeto',
  description: 'Put your merged streak up against your friends.',
};

export default function ComparePage() {
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
      </nav>

      <section className="wrap" style={{ paddingTop: 30, paddingBottom: 70 }}>
        <div className="eyebrow">leaderboard</div>
        <h1 className="display" style={{ fontSize: 'clamp(42px, 7vw, 74px)', marginTop: 16 }}>
          Whose streak is
          <br />
          <span style={{ fontStyle: 'italic', color: 'var(--flame-hot)' }}>actually</span> longest?
        </h1>
        <p className="dim" style={{ fontSize: 18, lineHeight: 1.55, maxWidth: 580, marginTop: 22 }}>
          Add your friends by handle. Everyone&rsquo;s platforms get merged the same
          way, so a GitHub-only streak and a LeetCode-only streak finally sit on
          the same scale.
        </p>

        <div style={{ marginTop: 38 }}>
          <Leaderboard />
        </div>
      </section>
    </main>
  );
}
