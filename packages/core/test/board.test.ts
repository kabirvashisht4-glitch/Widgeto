import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decodeSlug, encodeSlug, PLATFORM_IDS } from '../src/index.ts';
import type { HandleMap } from '../src/index.ts';

/**
 * The leaderboard parses what people type through the shared slug codec. It
 * used to keep a private copy of the platform table, which silently stopped
 * understanding Stack Overflow the moment that connector was added — so these
 * tests pin the property that broke: the codec must cover every registered
 * platform, with no second list to fall out of step.
 */

/** Mirrors the leaderboard's parser: a bare handle means GitHub. */
function parsePerson(input: string): HandleMap | null {
  const trimmed = input.trim();
  if (!trimmed) return null;
  const handles = decodeSlug(trimmed);
  if (Object.keys(handles).length > 0) return handles;
  return decodeSlug(`gh-${trimmed}`);
}

test('every registered platform round-trips through the codec', () => {
  // The guard against a hand-maintained second list drifting from the registry.
  for (const platform of PLATFORM_IDS) {
    const slug = encodeSlug({ [platform]: 'someone' } as HandleMap);
    assert.notEqual(slug, '', `${platform} has no short code`);

    const decoded = decodeSlug(slug);
    assert.deepEqual(
      decoded,
      { [platform]: 'someone' },
      `${platform} does not survive a round trip`,
    );
  }
});

test('a bare handle is read as GitHub', () => {
  assert.deepEqual(parsePerson('torvalds'), { github: 'torvalds' });
});

test('an explicit prefix wins over the GitHub default', () => {
  assert.deepEqual(parsePerson('lc-lee215'), { leetcode: 'lee215' });
  assert.deepEqual(parsePerson('so-22656'), { stackoverflow: '22656' });
});

test('a multi-platform slug parses as one person', () => {
  assert.deepEqual(parsePerson('gh-torvalds+cf-tourist+so-22656'), {
    github: 'torvalds',
    codeforces: 'tourist',
    stackoverflow: '22656',
  });
});

test('a hyphenated handle is not mistaken for a prefix', () => {
  assert.deepEqual(parsePerson('kabirvashisht4-glitch'), {
    github: 'kabirvashisht4-glitch',
  });
});

test('empty input is nothing, not an empty person', () => {
  assert.equal(parsePerson(''), null);
  assert.equal(parsePerson('   '), null);
});

test('a pasted profile URL works as a board entry', () => {
  assert.deepEqual(parsePerson('gh-https://github.com/torvalds'), { github: 'torvalds' });
});

test('a board round-trips through a shareable query string', () => {
  const board = ['torvalds', 'gh-you+lc-you', 'so-22656'];
  const encoded = board.join(',');

  const decoded = new URLSearchParams(`p=${encodeURIComponent(encoded)}`)
    .get('p')!
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  assert.deepEqual(decoded, board);
  assert.deepEqual(parsePerson(decoded[1]), { github: 'you', leetcode: 'you' });
});
