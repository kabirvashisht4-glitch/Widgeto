/**
 * The social card for the site itself.
 *
 * The profile card shows a specific person's streak; this one has to sell the
 * idea to someone who has never heard of it, so it leads with the problem —
 * four platforms each telling you your streak is broken — and answers with one
 * number.
 */
import { ImageResponse } from 'next/og';

export const runtime = 'nodejs';
export const alt = 'Widgeto — one coding streak across every platform you code on';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

const PLATFORMS: [string, string][] = [
  ['GitHub', '#3fb950'],
  ['Codeforces', '#58a6ff'],
  ['LeetCode', '#ffa657'],
  ['AtCoder', '#d0b070'],
];

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          background: '#09090b',
          padding: 72,
          color: '#fafafa',
          fontFamily: 'sans-serif',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', fontSize: 22, letterSpacing: 8, color: '#8b8b95' }}>
            WIDGETO
          </div>
          <div
            style={{
              display: 'flex',
              fontSize: 92,
              fontWeight: 800,
              letterSpacing: -4,
              lineHeight: 1.04,
              marginTop: 26,
              maxWidth: 940,
            }}
          >
            One streak. Every platform you code on.
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', fontSize: 30, color: '#8b8b95', maxWidth: 900 }}>
            {'You don’t have four streaks. You have one habit, scattered.'}
          </div>

          <div style={{ display: 'flex', gap: 34, marginTop: 34 }}>
            {PLATFORMS.map(([name, color]) => (
              <div key={name} style={{ display: 'flex', alignItems: 'center' }}>
                <div style={{ display: 'flex', width: 26, height: 26, background: color }} />
                <div style={{ display: 'flex', fontSize: 26, color: '#8b8b95', marginLeft: 12 }}>
                  {name}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    ),
    size,
  );
}
