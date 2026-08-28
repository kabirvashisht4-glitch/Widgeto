import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decodeSlug, encodeSlug, describeHandles } from '../src/util/slug.ts';

test('encodes handles in a stable order', () => {
  const a = encodeSlug({ leetcode: 'lee215', github: 'torvalds' });
  const b = encodeSlug({ github: 'torvalds', leetcode: 'lee215' });
  assert.equal(a, b, 'insertion order must not change the URL');
  assert.equal(a, 'gh-torvalds+lc-lee215');
});

test('round-trips', () => {
  const handles = { github: 'torvalds', codeforces: 'tourist', leetcode: 'lee215', atcoder: 'tourist' };
  assert.deepEqual(decodeSlug(encodeSlug(handles)), handles);
});

test('handles containing hyphens survive — split on the FIRST hyphen only', () => {
  const slug = encodeSlug({ github: 'kabirvashisht4-glitch' });
  assert.equal(slug, 'gh-kabirvashisht4-glitch');
  assert.deepEqual(decodeSlug(slug), { github: 'kabirvashisht4-glitch' });
});

test('a space standing in for a plus still decodes', () => {
  // Some clients hand back a decoded `+` as a space.
  assert.deepEqual(decodeSlug('gh-torvalds cf-tourist'), {
    github: 'torvalds',
    codeforces: 'tourist',
  });
});

test('unknown platforms and junk segments are skipped, not fatal', () => {
  assert.deepEqual(decodeSlug('gh-torvalds+xx-nobody+garbage+'), { github: 'torvalds' });
});

test('a pasted URL inside a slug is still normalized', () => {
  assert.deepEqual(decodeSlug('gh-https://github.com/torvalds'), { github: 'torvalds' });
});

test('empty input yields no handles rather than throwing', () => {
  assert.deepEqual(decodeSlug(''), {});
  assert.equal(encodeSlug({}), '');
});

test('describes handles for titles', () => {
  assert.equal(describeHandles({ github: 'torvalds' }), 'torvalds');
  assert.equal(
    describeHandles({ github: 'torvalds', codeforces: 'tourist', leetcode: 'lee215' }),
    'torvalds, tourist and lee215',
  );
  assert.equal(describeHandles({}), 'nobody');
});
