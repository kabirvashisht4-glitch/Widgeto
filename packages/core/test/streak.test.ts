import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildHeatmap, computeStreak, intensityLevels, mergeDays } from '../src/streak.ts';
import { addDays } from '../src/util/time.ts';

const TZ = 'Asia/Kolkata';
// A fixed instant so tests never depend on when they run.
// 2026-08-26T12:00:00+05:30
const NOW = Date.parse('2026-08-26T06:30:00Z');
const TODAY = '2026-08-26';

const map = (dates: string[]) => new Map(dates.map((d) => [d, 1]));

test('merges platforms into one timeline, summing same-day activity', () => {
  const merged = mergeDays([
    [{ date: '2026-08-25', count: 3 }, { date: '2026-08-26', count: 1 }],
    [{ date: '2026-08-26', count: 4 }],
  ]);
  assert.equal(merged.get('2026-08-25'), 3);
  assert.equal(merged.get('2026-08-26'), 5, 'same day on two platforms adds up');
  assert.equal(merged.size, 2);
});

test('activity on any one platform keeps the day alive', () => {
  // Nothing on GitHub today, but a Codeforces submission — the day counts.
  const merged = mergeDays([[], [{ date: TODAY, count: 1 }]]);
  const s = computeStreak(merged, { timezone: TZ, now: NOW });
  assert.equal(s.activeToday, true);
  assert.equal(s.currentStreak, 1);
});

test('an empty today does NOT break a live streak — it is at-risk', () => {
  const merged = map([addDays(TODAY, -1), addDays(TODAY, -2), addDays(TODAY, -3)]);
  const s = computeStreak(merged, { timezone: TZ, now: NOW });
  assert.equal(s.status, 'at-risk');
  assert.equal(s.currentStreak, 3, 'the run so far still stands; today is merely pending');
  assert.equal(s.activeToday, false);
});

test('the same streak flips to safe once today lands', () => {
  const merged = map([TODAY, addDays(TODAY, -1), addDays(TODAY, -2), addDays(TODAY, -3)]);
  const s = computeStreak(merged, { timezone: TZ, now: NOW });
  assert.equal(s.status, 'safe');
  assert.equal(s.currentStreak, 4);
  assert.equal(s.streakStart, addDays(TODAY, -3));
});

test('a missed yesterday with an empty today is genuinely broken', () => {
  const merged = map([addDays(TODAY, -2), addDays(TODAY, -3)]);
  const s = computeStreak(merged, { timezone: TZ, now: NOW });
  assert.equal(s.status, 'broken');
  assert.equal(s.currentStreak, 0);
  assert.equal(s.streakStart, null);
});

test('coding today after missing yesterday starts a fresh 1-day streak', () => {
  const merged = map([TODAY, addDays(TODAY, -2), addDays(TODAY, -3)]);
  const s = computeStreak(merged, { timezone: TZ, now: NOW });
  assert.equal(s.status, 'safe');
  assert.equal(s.currentStreak, 1);
});

test('streaks survive month and year boundaries', () => {
  const dates = ['2025-12-30', '2025-12-31', '2026-01-01', '2026-01-02'];
  const s = computeStreak(map(dates), { timezone: TZ, now: Date.parse('2026-01-02T06:30:00Z') });
  assert.equal(s.currentStreak, 4, 'New Year must not reset the run');
  assert.equal(s.longestStreak, 4);
});

test('longest streak is found even when it is not the current one', () => {
  const merged = map([
    '2026-01-01', '2026-01-02', '2026-01-03', '2026-01-04', '2026-01-05', // 5
    '2026-03-01', '2026-03-02',                                            // 2
    TODAY,                                                                 // 1
  ]);
  const s = computeStreak(merged, { timezone: TZ, now: NOW });
  assert.equal(s.longestStreak, 5);
  assert.equal(s.currentStreak, 1);
});

test('timezone decides the day boundary', () => {
  // 2026-08-26T19:00Z is already the 27th in Kolkata (+05:30) but still the
  // 26th in New York (-04:00). The same data yields a different "today".
  const instant = Date.parse('2026-08-26T19:00:00Z');
  const merged = map(['2026-08-26']);

  const kolkata = computeStreak(merged, { timezone: 'Asia/Kolkata', now: instant });
  const newYork = computeStreak(merged, { timezone: 'America/New_York', now: instant });

  assert.equal(kolkata.today, '2026-08-27');
  assert.equal(kolkata.status, 'at-risk', 'already tomorrow in India — today is unstarted');
  assert.equal(newYork.today, '2026-08-26');
  assert.equal(newYork.status, 'safe', 'still today in New York — the day is done');
});

test('empty input is a broken zero streak, not a crash', () => {
  const s = computeStreak(new Map(), { timezone: TZ, now: NOW });
  assert.deepEqual(
    { streak: s.currentStreak, longest: s.longestStreak, status: s.status, total: s.totalContributions },
    { streak: 0, longest: 0, status: 'broken', total: 0 },
  );
});

test('totals count days and contributions separately', () => {
  const merged = mergeDays([[{ date: '2026-08-24', count: 10 }, { date: '2026-08-25', count: 5 }]]);
  const s = computeStreak(merged, { timezone: TZ, now: NOW });
  assert.equal(s.totalActiveDays, 2);
  assert.equal(s.totalContributions, 15);
});

test('heatmap is dense, gap-filled and ends on today', () => {
  const merged = map([TODAY, addDays(TODAY, -3)]);
  const grid = buildHeatmap(merged, 7, TZ, NOW);
  assert.equal(grid.length, 7);
  assert.equal(grid[6].date, TODAY);
  assert.equal(grid[0].date, addDays(TODAY, -6));
  assert.equal(grid[5].count, 0, 'quiet days are present as zeroes, not missing');
  assert.equal(grid[3].count, 1);
});

test('intensity scales to the user, not to an absolute number', () => {
  const casual = intensityLevels([{ date: 'a', count: 0 }, { date: 'b', count: 1 }, { date: 'c', count: 3 }]);
  const heavy = intensityLevels([{ date: 'a', count: 0 }, { date: 'b', count: 40 }, { date: 'c', count: 120 }]);
  assert.equal(casual[0], 0);
  assert.equal(casual[2], 4, "a casual user's best day is still a full-intensity square");
  assert.deepEqual(casual, heavy, 'the same shape of effort reads the same at any scale');
});
