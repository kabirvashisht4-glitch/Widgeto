## What this changes

<!-- And why. The code already says what; the reasoning is the useful part. -->

## Checks

- [ ] `npm test && npm run typecheck`
- [ ] `cd apps/mobile && flutter analyze && flutter test`
- [ ] Goldens regenerated if the change moves pixels

## If this adds a connector

- [ ] Failure returns `{ ok: false, error }` rather than throwing
- [ ] `precision` is set honestly (`exact` vs `utc-day`)
- [ ] Public data only — no password, no session cookie
- [ ] Paginates politely and caps its requests
