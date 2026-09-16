# Contributing to Widgeto

Thanks for looking. The most useful contribution is usually **a new connector**
— that is the whole value of the project, and it is deliberately the easiest
thing to add.

## Setup

```bash
npm install
echo "GITHUB_TOKEN=$(gh auth token)" > apps/web/.env.local
npm run dev            # http://localhost:3210
npm test               # engine + API
```

For the app you also need [Flutter](https://docs.flutter.dev/get-started/install):

```bash
cd apps/mobile && flutter test
```

## Adding a platform

One file, one registry line. Nothing downstream changes.

1. **Write the connector** in `packages/core/src/connectors/<platform>.ts`. It
   returns a `PlatformResult`: a sparse list of day counts plus some profile
   stats.

2. **Register it** in `packages/core/src/connectors/index.ts` and add the id to
   `PlatformId` in `types.ts`.

3. **Give it a colour** in the site's `globals.css`, the app's `theme.dart` and
   the badge renderer. The four existing hues are load-bearing — the grid is
   readable only because green always means GitHub — so pick something
   distinguishable from them in both themes.

4. **Add a test.** Pure logic goes in `packages/core/test/`; don't write a test
   that calls the live API, because then somebody else's outage fails your pull
   request. The nightly CI job covers live connectors.

### Rules a connector must follow

- **Failure is a value, not an exception.** Return `{ ok: false, error }`. One
  dead platform greys out one row; it must never take the widget down.
- **Say how precise your days are.** `precision: 'exact'` if the API gives
  per-event timestamps, `'utc-day'` if it only publishes a UTC calendar grid.
  This is surfaced in the UI rather than hidden.
- **Public data only.** Never ask for a password or a session cookie. If a
  platform has no public profile endpoint, it needs a real OAuth flow.
- **Be a polite guest.** Cache, back off, cap your pagination. Two of the
  current connectors are community services that can block us for everyone.

## Style

- Comments explain *why*, not *what*. The code already says what.
- Match the surrounding code rather than introducing a new idiom.
- Keep commit subjects short and in the imperative; put the reasoning in the
  body.

## Design

The site and app share one rule: **colour means something.** The only hues are
the platform identities and the two status signals; everything else is black on
white or white on black. If you are adding UI, spend borders and type rather
than colour.

Goldens (`apps/mobile/test/golden_test.dart`) render real screens to PNG. If
your change moves pixels, regenerate them and include the diff:

```bash
cd apps/mobile && flutter test --update-goldens
```

## Before opening a pull request

```bash
npm test && npm run typecheck
cd apps/mobile && flutter analyze && flutter test
```

CI runs the same three. Green is the bar.
