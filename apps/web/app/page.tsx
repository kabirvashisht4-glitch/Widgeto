import Link from 'next/link';
import StreakStudio from './components/StreakStudio';

const PLATFORMS = [
  {
    name: 'GitHub',
    color: '#39d353',
    support: 'official' as const,
    detail: 'Official GraphQL contribution calendar. Commits, PRs, issues, reviews.',
  },
  {
    name: 'Codeforces',
    color: '#4aa3e0',
    support: 'official' as const,
    detail: 'Official public API. Per-submission timestamps, so days are exact.',
  },
  {
    name: 'AtCoder',
    color: '#b08d4f',
    support: 'unofficial' as const,
    detail: 'Community mirror at kenkoooo. Per-submission timestamps, so days are exact.',
  },
  {
    name: 'LeetCode',
    color: '#ffa116',
    support: 'unofficial' as const,
    detail: 'Public profile endpoint. No official API exists, so this one is best-effort.',
  },
];

export default function Home() {
  return (
    <main>
      {/* ---------- nav ---------- */}
      <nav className="wrap" style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '26px 24px' }}>
        <Mark />
        <span style={{ fontWeight: 600, letterSpacing: '-0.01em' }}>Widgeto</span>
        <span className="tag" style={{ marginLeft: 6 }}>alpha</span>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 20 }}>
          <Link href="/compare" className="dim" style={{ fontSize: 14, textDecoration: 'none' }}>
            Leaderboard
          </Link>
          <a
            href="https://github.com/kabirvashisht4-glitch/Widgeto"
            className="dim"
            style={{ fontSize: 14, textDecoration: 'none' }}
          >
            Source
          </a>
        </div>
      </nav>

      {/* ---------- hero ---------- */}
      <section className="wrap" style={{ paddingTop: 40, paddingBottom: 56 }}>
        <div className="eyebrow">github · codeforces · leetcode · atcoder</div>
        <h1
          className="display"
          style={{ fontSize: 'clamp(52px, 9vw, 104px)', marginTop: 18, maxWidth: 900 }}
        >
          One streak.
          <br />
          <span style={{ fontStyle: 'italic', color: 'var(--flame-hot)' }}>Every</span> platform
          you code on.
        </h1>

        <p
          className="dim"
          style={{ fontSize: 19, lineHeight: 1.55, maxWidth: 620, marginTop: 26 }}
        >
          You don&rsquo;t have a GitHub streak and a LeetCode streak. You have{' '}
          <strong style={{ color: 'var(--text)', fontWeight: 600 }}>one habit</strong> scattered
          across five sites. Widgeto merges them into a single number and puts it on your home
          screen.
        </p>

        <div style={{ marginTop: 40 }}>
          <StreakStudio />
        </div>
      </section>

      {/* ---------- the colour language ---------- */}
      <section className="wrap" style={{ padding: '64px 24px' }}>
        <div style={{ display: 'grid', gap: 44, gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))' }}>
          <div>
            <div className="eyebrow">the grid</div>
            <h2 className="display" style={{ fontSize: 'clamp(32px, 4.4vw, 46px)', marginTop: 14 }}>
              Colour tells you where the day went.
            </h2>
            <p className="dim" style={{ fontSize: 16, lineHeight: 1.65, marginTop: 18, maxWidth: 460 }}>
              A normal contribution grid has one colour and one message: you did something. Ours
              paints each square with the platform you were actually on — and blends them on days
              you touched more than one. A year of your habit, readable in a glance.
            </p>
          </div>

          <div className="card" style={{ padding: 26 }}>
            <div style={{ display: 'grid', gap: 16 }}>
              <Swatch color="#39d353" label="GitHub day" note="shipped code" />
              <Swatch color="#ffa116" label="LeetCode day" note="ground problems" />
              <Swatch color="#4aa3e0" label="Codeforces day" note="entered a contest" />
              <hr className="rule" />
              <Swatch
                color="linear-gradient(100deg, #39d353, #ffa116)"
                label="Both"
                note="the colours mix — the good days"
              />
            </div>
          </div>
        </div>
      </section>

      {/* ---------- what's connected ---------- */}
      <section className="wrap" style={{ padding: '48px 24px' }}>
        <div className="eyebrow">connected</div>
        <h2 className="display" style={{ fontSize: 'clamp(30px, 4vw, 42px)', marginTop: 12 }}>
          {PLATFORMS.length} now. More landing.
        </h2>

        <div style={{ display: 'grid', gap: 12, marginTop: 26 }}>
          {PLATFORMS.map((p) => (
            <div
              key={p.name}
              className="card"
              style={{
                padding: '18px 22px',
                display: 'flex',
                alignItems: 'center',
                gap: 16,
                flexWrap: 'wrap',
                borderRadius: 14,
              }}
            >
              <span style={{ width: 10, height: 10, borderRadius: 3, background: p.color, flexShrink: 0 }} />
              <span style={{ fontWeight: 600, minWidth: 110 }}>{p.name}</span>
              <span className={`tag ${p.support === 'official' ? 'ok' : 'warn'}`}>{p.support}</span>
              <span className="dim" style={{ fontSize: 14, flex: 1, minWidth: 240 }}>
                {p.detail}
              </span>
            </div>
          ))}
        </div>

        <p className="faint" style={{ fontSize: 13.5, lineHeight: 1.6, marginTop: 20, maxWidth: 620 }}>
          Marked honestly on purpose. Unofficial sources can break without warning, so a dead
          connector greys out one row — it never takes the widget down with it. CodeChef and Stack Overflow are next.
        </p>
      </section>

      {/* ---------- readme badge ---------- */}
      <section className="wrap" style={{ padding: '48px 24px' }}>
        <div className="eyebrow">embed</div>
        <h2 className="display" style={{ fontSize: 'clamp(30px, 4vw, 42px)', marginTop: 12 }}>
          Your streak, in your README.
        </h2>
        <p className="dim" style={{ fontSize: 16, lineHeight: 1.65, marginTop: 18, maxWidth: 560 }}>
          A live SVG that updates on its own. Build your streak above, then copy
          the snippet from your profile page.
        </p>

        <div className="card" style={{ padding: 26, marginTop: 24, display: 'grid', gap: 18 }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/api/badge?github=torvalds&codeforces=tourist&leetcode=lee215&style=card"
            alt="Example Widgeto streak card"
            style={{ maxWidth: '100%' }}
          />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/api/badge?github=torvalds&codeforces=tourist&style=flat"
            alt="Example Widgeto flat streak badge"
            style={{ height: 28 }}
          />
        </div>
      </section>

      {/* ---------- why ---------- */}
      <section className="wrap" style={{ padding: '48px 24px 72px' }}>
        <div style={{ display: 'grid', gap: 16, gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))' }}>
          <Feature
            title="One number, not five"
            body="Do anything on any platform and the day counts. The habit is the thing worth tracking — not which site happened to host it."
          />
          <Feature
            title="A nudge before midnight"
            body="If the day is still empty at 9pm, your phone says so. The widget shows the streak; the notification is what saves it."
          />
          <Feature
            title="A scoreboard with your friends"
            body="Everyone's platforms merge the same way, so a GitHub-only streak and a LeetCode-only streak finally sit on one scale."
          />
          <Feature
            title="Just type your handle"
            body="Every source is public profile data, so there's no OAuth wall and no password to hand over. Thirty seconds from open to working widget."
          />
        </div>
      </section>

      {/* ---------- footer ---------- */}
      <footer style={{ borderTop: '1px solid var(--line)', padding: '32px 0 56px' }}>
        <div className="wrap" style={{ display: 'flex', gap: 18, flexWrap: 'wrap', alignItems: 'center' }}>
          <Mark />
          <span className="faint" style={{ fontSize: 13 }}>
            Widgeto is independent and not affiliated with GitHub, Codeforces or LeetCode.
          </span>
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 18 }}>
            <Link className="mono faint" style={{ fontSize: 12 }} href="/compare">
              leaderboard →
            </Link>
            <a
              className="mono faint"
              style={{ fontSize: 12 }}
              href="https://github.com/kabirvashisht4-glitch/Widgeto"
            >
              source →
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}

function Swatch({ color, label, note }: { color: string; label: string; note: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
      <span
        style={{
          width: 30,
          height: 30,
          borderRadius: 7,
          background: color.startsWith('linear') ? color : color,
          flexShrink: 0,
        }}
      />
      <div>
        <div style={{ fontWeight: 600, fontSize: 14.5 }}>{label}</div>
        <div className="faint" style={{ fontSize: 12.5 }}>{note}</div>
      </div>
    </div>
  );
}

function Feature({ title, body }: { title: string; body: string }) {
  return (
    <div className="card" style={{ padding: 24 }}>
      <h3 style={{ margin: 0, fontSize: 17, fontWeight: 600, letterSpacing: '-0.01em' }}>{title}</h3>
      <p className="dim" style={{ fontSize: 14.5, lineHeight: 1.6, marginTop: 10, marginBottom: 0 }}>
        {body}
      </p>
    </div>
  );
}

/** A tiny three-square mark: the contribution grid, reduced to its atom. */
function Mark() {
  return (
    <svg width="22" height="22" viewBox="0 0 22 22" aria-hidden="true">
      <rect x="1" y="12" width="8" height="8" rx="2" fill="#39d353" />
      <rect x="12" y="12" width="8" height="8" rx="2" fill="#ffa116" />
      <rect x="6.5" y="1.5" width="8" height="8" rx="2" fill="#4aa3e0" />
    </svg>
  );
}
