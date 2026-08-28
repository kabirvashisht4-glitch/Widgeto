'use client';

import { useCallback, useEffect, useState } from 'react';
import type { PlatformId, StreakSummary } from '@widgeto/core';
import { PLATFORM_COLORS } from './ContributionGrid';

/**
 * A friends leaderboard.
 *
 * This audience is competitive by construction — it is the entire reason they
 * have Codeforces ratings. A shared scoreboard is the growth loop a solo streak
 * widget does not have: you cannot rank yourself alone, so adding people is the
 * natural next action.
 */

interface Person {
  id: number;
  input: string;
  loading: boolean;
  error?: string;
  summary?: StreakSummary;
  handles?: { platform: PlatformId; handle: string }[];
  slug?: string;
}

let nextId = 1;
const blank = (input = ''): Person => ({ id: nextId++, input, loading: false });

const SHORT: Record<string, PlatformId> = {
  gh: 'github',
  cf: 'codeforces',
  lc: 'leetcode',
  ac: 'atcoder',
};
const TO_SHORT = Object.fromEntries(Object.entries(SHORT).map(([s, l]) => [l, s]));

/**
 * People will type `torvalds`, `gh-torvalds`, or a whole slug. Accept all
 * three; a bare handle is assumed to be GitHub, because that is the one
 * account everyone in this audience has.
 */
function toQuery(input: string): string | null {
  const parts = input.trim().split('+').filter(Boolean);
  if (parts.length === 0) return null;

  const params = new URLSearchParams();
  for (const part of parts) {
    const cut = part.indexOf('-');
    const prefix = cut > 0 ? part.slice(0, cut).toLowerCase() : '';
    if (SHORT[prefix]) params.set(SHORT[prefix], part.slice(cut + 1));
    else params.set('github', part);
  }
  return params.toString() || null;
}

export default function Leaderboard() {
  const [people, setPeople] = useState<Person[]>([
    blank('torvalds'),
    blank('gh-kabirvashisht4-glitch'),
    blank(),
  ]);
  const [timezone, setTimezone] = useState('UTC');

  useEffect(() => {
    setTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');
  }, []);

  const rank = useCallback(async () => {
    const targets = people.filter((p) => p.input.trim());
    if (targets.length === 0) return;

    setPeople((ps) => ps.map((p) => (p.input.trim() ? { ...p, loading: true, error: undefined } : p)));

    // Everyone is looked up concurrently; one bad handle must not stall the
    // rest of the board.
    await Promise.all(
      targets.map(async (person) => {
        const query = toQuery(person.input);
        const patch = (next: Partial<Person>) =>
          setPeople((ps) => ps.map((p) => (p.id === person.id ? { ...p, ...next } : p)));

        if (!query) return patch({ loading: false });

        try {
          const res = await fetch(
            `/api/streak?${query}&tz=${encodeURIComponent(timezone)}&days=120`,
          );
          const body = await res.json();
          if (!res.ok) throw new Error(body.error ?? 'lookup failed');

          const live = (body.platforms as { ok: boolean; platform: PlatformId; handle: string }[])
            .filter((p) => p.ok);
          if (live.length === 0) throw new Error('no platform answered');

          patch({
            loading: false,
            summary: body.summary,
            handles: live.map((p) => ({ platform: p.platform, handle: p.handle })),
            slug: live.map((p) => `${TO_SHORT[p.platform]}-${p.handle}`).join('+'),
          });
        } catch (err) {
          patch({ loading: false, error: (err as Error).message });
        }
      }),
    );
  }, [people, timezone]);

  const ranked = people
    .filter((p) => p.summary)
    .sort((a, b) => b.summary!.currentStreak - a.summary!.currentStreak);

  const leader = ranked[0]?.summary?.currentStreak ?? 0;
  const busy = people.some((p) => p.loading);

  return (
    <div style={{ display: 'grid', gap: 22 }}>
      <div style={{ display: 'grid', gap: 10 }}>
        {people.map((person, i) => (
          <div key={person.id} style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <span className="mono faint" style={{ fontSize: 12, width: 18, flexShrink: 0 }}>
              {i + 1}
            </span>
            <label className="field" style={{ flex: 1, minWidth: 0 }}>
              <input
                value={person.input}
                spellCheck={false}
                autoComplete="off"
                placeholder="handle, or gh-you+lc-you"
                aria-label={`Person ${i + 1}`}
                onChange={(e) =>
                  setPeople((ps) =>
                    ps.map((p) => (p.id === person.id ? { ...p, input: e.target.value } : p)),
                  )
                }
                onKeyDown={(e) => {
                  if (e.key === 'Enter') rank();
                }}
              />
            </label>
            <button
              className="btn btn-ghost"
              type="button"
              aria-label={`Remove person ${i + 1}`}
              style={{ width: 46, padding: 0, fontSize: 18, lineHeight: 1 }}
              onClick={() =>
                setPeople((ps) => (ps.length > 1 ? ps.filter((p) => p.id !== person.id) : ps))
              }
            >
              ×
            </button>
          </div>
        ))}
      </div>

      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
        <button className="btn" type="button" onClick={rank} disabled={busy}>
          {busy ? 'Merging…' : 'Rank them'}
        </button>
        <button
          className="btn btn-ghost"
          type="button"
          disabled={people.length >= 8}
          onClick={() => setPeople((ps) => [...ps, blank()])}
        >
          Add person
        </button>
        <span className="mono faint" style={{ fontSize: 11 }}>
          last 120 days · {timezone}
        </span>
      </div>

      {ranked.length > 0 && (
        <div className="card" style={{ padding: 6 }}>
          {ranked.map((person, i) => {
            const s = person.summary!;
            const share = leader > 0 ? s.currentStreak / leader : 0;
            const colors = (person.handles ?? []).map((h) => PLATFORM_COLORS[h.platform]);
            return (
              <div
                key={person.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 16,
                  padding: 16,
                  borderBottom: i < ranked.length - 1 ? '1px solid var(--line)' : 'none',
                }}
              >
                <span
                  className="mono"
                  style={{
                    fontSize: 15,
                    width: 24,
                    flexShrink: 0,
                    fontWeight: i === 0 ? 700 : 400,
                    color: i === 0 ? 'var(--flame-hot)' : 'var(--text-faint)',
                  }}
                >
                  {i + 1}
                </span>

                <div style={{ flex: 1, minWidth: 0 }}>
                  <a
                    href={`/u/${person.slug}`}
                    className="mono"
                    style={{ fontSize: 13.5, textDecoration: 'none' }}
                  >
                    {person.handles?.map((h) => h.handle).join(' · ')}
                  </a>
                  {/* Bars are relative to the leader, so the gap is what you
                      see rather than two numbers you have to subtract. */}
                  <div
                    style={{
                      height: 5,
                      borderRadius: 3,
                      background: 'var(--surface-2)',
                      marginTop: 8,
                      overflow: 'hidden',
                    }}
                  >
                    <div
                      style={{
                        width: `${Math.max(share * 100, 2)}%`,
                        height: '100%',
                        borderRadius: 3,
                        background:
                          colors.length > 1
                            ? `linear-gradient(90deg, ${colors.join(', ')})`
                            : colors[0] ?? 'var(--github)',
                        transition: 'width 700ms cubic-bezier(.2,.8,.3,1)',
                      }}
                    />
                  </div>
                </div>

                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  <div className="mono" style={{ fontSize: 21, fontWeight: 600 }}>
                    {s.currentStreak}
                  </div>
                  <div className="eyebrow" style={{ fontSize: 9 }}>
                    {s.status === 'safe' ? 'done today' : s.status === 'at-risk' ? 'pending' : 'broken'}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {people
        .filter((p) => p.error)
        .map((p) => (
          <div key={p.id} className="mono" style={{ fontSize: 12.5, color: 'var(--danger)' }}>
            {p.input} — {p.error}
          </div>
        ))}
    </div>
  );
}
