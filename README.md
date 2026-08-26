# Widgeto

**One streak across every platform you code on.**

You don't have a GitHub streak and a LeetCode streak. You have one habit
scattered across several sites. Widgeto merges them into a single number and
puts it on your home screen.

```
  57 day unified streak   ⚠ at risk — ends at midnight
  longest 80d · 355 active days · 3,968 contributions
```

## What's here

| Package | What it is | State |
|---|---|---|
| `packages/core` | Connectors + streak engine. Zero dependencies, runs in Node, Next and Workers. | **Verified against live APIs**, 14 tests |
| `apps/web` | Landing page that is also the onboarding flow, plus `/api/streak` | **Verified in browser** |
| `apps/mobile` | Flutter app + iOS/Android widget faces | Written, not yet compiled |

## Try it in the terminal

```bash
node packages/core/bin/widgeto.ts --github torvalds --codeforces tourist --leetcode lee215
```

Needs a GitHub token in `$GITHUB_TOKEN`, or an authenticated `gh` CLI. GitHub's
GraphQL API rejects anonymous requests even for public contribution calendars;
the other two connectors need no credentials at all.

## Run the site

```bash
npm install && npm run dev --workspace @widgeto/web
```

Put a token in `apps/web/.env.local` as `GITHUB_TOKEN=…`, then open
<http://localhost:3210>.

## How it fits together

```
 GitHub ─┐
 Codef.  ├─► connectors ─► local-day normalisation ─► one merged timeline
 LeetC. ─┘                                                    │
                                                    ┌─────────┴─────────┐
                                              /api/streak         streak engine
                                                    │
                                          ┌─────────┴─────────┐
                                       website            Flutter app
                                                              │
                                                    iOS + Android widget faces
```

Every connector reduces to the same shape — a sparse list of day counts in the
user's timezone — so adding a platform is one file plus one registry line, and
nothing downstream changes.

## Three decisions worth knowing

**Timezone first.** Every day boundary resolves through the user's IANA zone.
GitHub and LeetCode only expose UTC calendar grids, so those are labelled
`utc-day` and surfaced in the UI rather than quietly papered over; Codeforces
gives per-submission timestamps, so its days are exact. An off-by-one hour in a
streak app isn't a rounding error, it's a broken promise.

**An empty today is `at-risk`, never `broken`.** The day isn't over. A naive
implementation zeroes your streak at 00:00 and demoralises you for the next
sixteen hours.

**Connector failure is a value, not an exception.** One platform being down
greys out one row. The widget is expected to render something every single time
it's asked.

## Connected platforms

| Platform | Access | Notes |
|---|---|---|
| GitHub | Official GraphQL | Needs a token even for public data |
| Codeforces | Official public API | Anonymous, ~1 req / 2s, exact timestamps |
| LeetCode | Unofficial | No official API exists — best-effort, treated as such |

Public profiles only. Widgeto never asks for a password or a session cookie.

## Credits

Architecture informed by [Forge](https://github.com/rakshityadav1868/github-widget)
by Rakshit Yadav (MIT), which solves the same Flutter + native widget bridge for
GitHub alone.

Widgeto is independent and not affiliated with GitHub, Codeforces or LeetCode.
