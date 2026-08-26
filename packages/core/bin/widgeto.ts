#!/usr/bin/env node
/**
 * Widgeto CLI — renders your unified streak in the terminal.
 *
 * This is the feasibility proof and the debugging tool: it exercises the exact
 * code path the phone widget uses, against the real upstream APIs.
 *
 *   node packages/core/bin/widgeto.ts --github torvalds --codeforces tourist
 *
 * The GitHub token is read from $GITHUB_TOKEN, or from `gh auth token`.
 */
import { execSync } from 'node:child_process';
import { aggregate } from '../src/aggregate.ts';
import { intensityLevels } from '../src/streak.ts';
import { CONNECTORS, PLATFORM_IDS } from '../src/connectors/index.ts';
import type { PlatformId, UnifiedActivity } from '../src/types.ts';

const C = {
  reset: '\x1b[0m', dim: '\x1b[2m', bold: '\x1b[1m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m',
  blue: '\x1b[34m', orange: '\x1b[38;5;208m', grey: '\x1b[38;5;240m',
};
// Ascending contribution-grid greens, matching the widget's palette.
const HEAT = ['\x1b[38;5;236m', '\x1b[38;5;22m', '\x1b[38;5;28m', '\x1b[38;5;34m', '\x1b[38;5;46m'];

function parseArgs(argv: string[]) {
  const args: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].slice(2);
      const value = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : 'true';
      args[key] = value;
    }
  }
  return args;
}

function githubToken(): string | undefined {
  if (process.env.GITHUB_TOKEN) return process.env.GITHUB_TOKEN;
  try {
    return execSync('gh auth token', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim() || undefined;
  } catch {
    return undefined;
  }
}

/** The contribution grid: weeks as columns, weekdays as rows, like GitHub. */
function renderHeatmap(activity: UnifiedActivity, weeks: number): string[] {
  const cells = activity.heatmap.slice(-weeks * 7);
  const levels = intensityLevels(cells);

  // Pad the front so the first column starts on a Sunday.
  const firstDow = new Date(`${cells[0].date}T12:00:00Z`).getUTCDay();
  const padded: (number | null)[] = [...Array(firstDow).fill(null), ...levels];

  const rows: string[] = [];
  for (let dow = 0; dow < 7; dow++) {
    let row = '';
    for (let w = 0; w * 7 + dow < padded.length; w++) {
      const level = padded[w * 7 + dow];
      row += level === null ? '  ' : `${HEAT[level]}■${C.reset} `;
    }
    rows.push(row);
  }
  return rows;
}

function statusBadge(status: string, streak: number): string {
  if (status === 'safe') return `${C.green}${C.bold}✓ safe${C.reset}`;
  if (status === 'at-risk') return `${C.yellow}${C.bold}⚠ at risk${C.reset} ${C.dim}— ${streak}-day run ends at midnight${C.reset}`;
  return `${C.red}${C.bold}✗ broken${C.reset}`;
}

const args = parseArgs(process.argv.slice(2));
const handles = Object.fromEntries(
  PLATFORM_IDS.filter((id) => args[id]).map((id) => [id, args[id]]),
) as Record<PlatformId, string>;

if (Object.keys(handles).length === 0) {
  console.log(`
${C.bold}Widgeto${C.reset} ${C.dim}— one streak across every platform you code on${C.reset}

  ${C.dim}usage:${C.reset} node packages/core/bin/widgeto.ts [--github H] [--codeforces H] [--leetcode H]
                 [--tz Asia/Kolkata] [--days 365] [--json]

  ${C.dim}platforms:${C.reset}
${PLATFORM_IDS.map((id) => {
  const c = CONNECTORS[id];
  const tag = c.support === 'official' ? `${C.green}official${C.reset}` : `${C.yellow}unofficial${C.reset}`;
  return `    --${id.padEnd(12)} ${c.name.padEnd(12)} ${tag}  ${C.dim}e.g. ${c.handleHint}${C.reset}`;
}).join('\n')}
`);
  process.exit(0);
}

const timezone = args.tz ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC';
const days = Number(args.days ?? 365);

const started = Date.now();
const activity = await aggregate(handles, { timezone, days, githubToken: githubToken() });
const elapsed = Date.now() - started;

if (args.json) {
  console.log(JSON.stringify(activity, null, 2));
  process.exit(0);
}

const { summary } = activity;

console.log(`\n  ${C.bold}WIDGETO${C.reset}  ${C.dim}${timezone} · today is ${summary.today} · fetched in ${elapsed}ms${C.reset}\n`);
console.log(`  ${C.bold}${C.green}${String(summary.currentStreak).padStart(3)}${C.reset} ${C.dim}day unified streak${C.reset}   ${statusBadge(summary.status, summary.currentStreak)}`);
console.log(`  ${C.dim}longest ${summary.longestStreak}d · ${summary.totalActiveDays} active days · ${summary.totalContributions.toLocaleString()} contributions${C.reset}\n`);

for (const row of renderHeatmap(activity, 53)) console.log(`  ${row}`);
console.log();

for (const p of activity.platforms) {
  const meta = CONNECTORS[p.platform];
  const label = `${meta.name}`.padEnd(12);
  if (!p.ok) {
    console.log(`  ${C.red}✗${C.reset} ${label} ${C.dim}@${p.handle}${C.reset}  ${C.red}${p.error}${C.reset}`);
    continue;
  }
  const stats = (p.profile?.stats ?? []).map((s) => `${C.bold}${s.value}${C.reset} ${C.dim}${s.label}${C.reset}`).join('  ');
  const fidelity = p.precision === 'exact' ? '' : ` ${C.grey}(utc-day)${C.reset}`;
  console.log(`  ${C.green}✓${C.reset} ${label} ${C.dim}@${p.handle}${C.reset}  ${stats}  ${C.dim}${p.days.length}d active${C.reset}${fidelity}`);
}
console.log();
