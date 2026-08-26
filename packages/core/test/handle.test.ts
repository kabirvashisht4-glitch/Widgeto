import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeHandle, normalizeHandles } from '../src/util/handle.ts';

test('a bare handle passes through', () => {
  assert.equal(normalizeHandle('torvalds'), 'torvalds');
  assert.equal(normalizeHandle('  tourist  '), 'tourist');
});

test('a pasted profile URL is reduced to the handle', () => {
  // The real case: a user pasted this and got a validation error.
  assert.equal(normalizeHandle('https://github.com/kabirvashisht4-glitch'), 'kabirvashisht4-glitch');
  assert.equal(normalizeHandle('github.com/torvalds'), 'torvalds');
  assert.equal(normalizeHandle('https://github.com/torvalds/'), 'torvalds');
});

test('routing segments are skipped, not mistaken for the handle', () => {
  assert.equal(normalizeHandle('https://leetcode.com/u/lee215/'), 'lee215');
  assert.equal(normalizeHandle('https://codeforces.com/profile/tourist'), 'tourist');
});

test('query strings and fragments are discarded', () => {
  assert.equal(normalizeHandle('https://codeforces.com/profile/tourist?locale=en'), 'tourist');
  assert.equal(normalizeHandle('https://github.com/torvalds#readme'), 'torvalds');
});

test('a leading @ is stripped', () => {
  assert.equal(normalizeHandle('@torvalds'), 'torvalds');
});

test('genuinely unusable input is still rejected', () => {
  assert.equal(normalizeHandle('not a handle!'), null);
  assert.equal(normalizeHandle(''), null);
  assert.equal(normalizeHandle('   '), null);
  assert.equal(normalizeHandle('https://github.com/'), null);
  assert.equal(normalizeHandle('a'.repeat(40)), null, 'longer than any platform allows');
});

test('a handle map is normalized entry by entry', () => {
  const { handles, rejected } = normalizeHandles({
    github: 'https://github.com/torvalds',
    codeforces: '@tourist',
    leetcode: 'not valid!',
  });
  assert.deepEqual(handles, { github: 'torvalds', codeforces: 'tourist' });
  assert.deepEqual(rejected, ['leetcode']);
});
