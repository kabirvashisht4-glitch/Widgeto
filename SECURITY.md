# Security

## Reporting a vulnerability

Please **do not open a public issue.** Use GitHub's
[private vulnerability reporting](https://github.com/kabirvashisht4-glitch/Widgeto/security/advisories/new)
so it can be fixed before it is public.

Expect an acknowledgement within a few days.

## What Widgeto handles

Deliberately very little, which is most of the security story:

- **No user accounts, no passwords, no sessions.** Handles are public
  usernames. Widgeto never asks for a password or a session cookie, and any
  build that did would be a bug worth reporting.
- **No user data at rest.** Streaks are computed per request and cached in
  memory for minutes. Handles you enter in the app stay on your device.
- **One secret**, `GITHUB_TOKEN`, server-side only. It should be a classic
  token with **no scopes** — it exists solely because GitHub's GraphQL API
  rejects anonymous requests even for public contribution calendars.

## If you self-host

- Give the token no scopes. It never needs write access or private repos.
- The public endpoints are rate-limited per client IP. That limit is in-process
  and correct for a single instance; behind more than one, move it to Redis or
  KV or the ceiling multiplies by your instance count.
- `/api/health` reports configuration only. It exposes no secrets and makes no
  upstream calls.
