'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { decodeSlug, encodeSlug } from '@widgeto/core';
import type { HandleMap, PlatformId, StreakSummary } from '@widgeto/core';
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

/**
 * People type `torvalds`, `gh-torvalds`, or a whole slug. All three work.
 *
 * Parsing goes through the shared slug codec rather than a second copy of the
 * platform table. This screen used to keep its own, and it silently stopped
 * understanding Stack Overflow the moment a platform was added to core —
 * exactly the drift one source of truth exists to prevent.
 *
 * A bare handle is assumed to be GitHub, because that is the one account
 * everyone in this audience has.
 */
function parsePerson(input: string): HandleMap | null {
  const trimmed = input.trim();
  if (!trimmed) return null;

  const handles = decodeSlug(trimmed);
  if (Object.keys(handles).length > 0) return handles;

  // No platform prefix anywhere — treat the whole thing as a GitHub handle.
  return decodeSlug(`gh-${trimmed}`);
}

function toQuery(input: string): string | null {
  const handles = parsePerson(input);
  if (!handles) return null;

  const params = new URLSearchParams();
  for (const [platform, handle] of Object.entries(handles)) params.set(platform, handle);
  return params.toString() || null;
}

/** `?p=gh-torvalds,gh-you+lc-you` — the board, in a link. */
function readBoardFromUrl(): string[] | null {
  if (typeof window === 'undefined') return null;
  const raw = new URLSearchParams(window.location.search).get('p');
  if (!raw) return null;
  const entries = raw.split(',').map((s) => s.trim()).filter(Boolean).slice(0, 8);
  return entries.length ? entries : null;
}

const DEFAULT_BOARD = ['torvalds', 'gh-kabirvashisht4-glitch', ''];

export default function Leaderboard() {
  // Seeded with the defaults on both the server and the first client render; a
  // shared board is applied after mount, because reading the URL during render
  // would make the two disagree.
  const [people, setPeople] = useState<Person[]>(DEFAULT_BOARD.map(blank));
  const [timezone, setTimezone] = useState('UTC');
  const [copied, setCopied] = useState(false);
  const autoRanked = useRef(false);
  const hydrated = useRef(false);
  // Lets `rank()` see the current roster without taking `people` as a
  // dependency, which would recreate it on every keystroke.
  const peopleRef = useRef(people);
  peopleRef.current = people;

  useEffect(() => {
    setTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');

    const shared = readBoardFromUrl();
    hydrated.current = true;
    if (!shared) return;

    // Seed and rank together: a shared link should show its board, not an
    // empty form, and splitting these across two effects is what raced.
    const seeded = shared.map(blank);
    setPeople(seeded);
    autoRanked.current = true;
    rank(seeded);
    // rank is stable across renders; this must run exactly once, on mount.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /**
   * Keep the address bar in step with the board.
   *
   * Derived from state in its own effect rather than written inside the rank
   * action: doing it there captured whatever `people` was when the callback
   * was created, so a board opened from a shared link promptly overwrote that
   * link with the defaults.
   */
  useEffect(() => {
    if (!hydrated.current) return;

    const board = people.map((p) => p.input.trim()).filter(Boolean);
    const url = new URL(window.location.href);
    if (board.length) url.searchParams.set('p', board.join(','));
    else url.searchParams.delete('p');

    // replaceState, not push: editing the board is not a navigation and should
    // not add a back-button step per keystroke.
    window.history.replaceState(null, '', url);
  }, [people]);

  const copyLink = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(window.location.href);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // Clipboard is blocked in some embedded contexts. The URL is in the
      // address bar either way, so this is not worth an error dialog.
    }
  }, []);

  /**
   * Rank an explicit roster.
   *
   * The roster is a parameter rather than something read from state, because
   * reading it from a closure raced the effect that seeds a shared board: the
   * two mount effects run in the same pass, so ranking started against the
   * default people, set `loading` on the freshly-seeded ones, and then patched
   * ids that no longer existed — leaving the board stuck on "Merging…" with
   * nothing ever arriving.
   */
  const rank = useCallback(
    async (roster?: Person[]) => {
      const current = roster ?? peopleRef.current;
      const targets = current.filter((p) => p.input.trim());
      if (targets.length === 0) return;

      const live = new Set(current.map((p) => p.id));
      setPeople((ps) =>
        ps.map((p) => (live.has(p.id) && p.input.trim() ? { ...p, loading: true, error: undefined } : p)),
      );

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
            slug: encodeSlug(
              Object.fromEntries(live.map((p) => [p.platform, p.handle])) as HandleMap,
            ),
          });
        } catch (err) {
          patch({ loading: false, error: (err as Error).message });
        }
      }),
    );
    },
    [timezone],
  );

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
        {/* Wrapped, not passed directly: `rank` takes an optional roster, and
            handing it to onClick would pass the click event as that roster. */}
        <button className="btn" type="button" onClick={() => rank()} disabled={busy}>
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
        <button
          className="btn btn-ghost"
          type="button"
          onClick={copyLink}
          disabled={!people.some((p) => p.input.trim())}
        >
          {copied ? 'Copied' : 'Copy link'}
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
                    color: i === 0 ? 'var(--text)' : 'var(--text-faint)',
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
                      height: 8,
                      background: 'var(--surface-2)',
                      border: '1px solid var(--line-soft)',
                      marginTop: 8,
                      overflow: 'hidden',
                    }}
                  >
                    <div
                      style={{
                        width: `${Math.max(share * 100, 2)}%`,
                        height: '100%',
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
