#!/usr/bin/env bash
# Build the Flutter app as an installable PWA into the website, where it is
# served at /app on the same deployment as the API.
#
# The output is COMMITTED. That is deliberate: a host like Vercel runs
# `next build` and has no Flutter SDK, so if the build were generated at deploy
# time /app would simply 404 for everyone who deploys this repo. Committing it
# means a fork deploys to a working app with no toolchain at all.
#
# Re-run this and commit the result whenever you change anything in apps/mobile.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/apps/web/public/app"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found — leaving the existing committed build in place."
  echo "The website and API build fine without it; install Flutter to rebuild the app."
  exit 0
fi

echo "Building the Widgeto app for web…"
cd "$root/apps/mobile"
flutter pub get
# base-href must match where it is served from, or every asset 404s.
flutter build web --release --pwa-strategy offline-first --base-href /app/

rm -rf "$out"
mkdir -p "$out"
cp -R build/web/. "$out/"

# CanvasKit is 36 MB and Flutter loads it from Google's CDN at runtime, so the
# local copy is dead weight in git. Dropping it takes the committed build from
# 40 MB to under 4 MB; the app has been verified to run without it.
rm -rf "$out/canvaskit"

size=$(find "$out" -type f -exec stat -f%z {} + | awk '{s+=$1} END {printf "%.1f", s/1048576}')
echo "App built into apps/web/public/app (${size} MB) — served at /app"
echo "Remember to commit it: the deploy has no Flutter SDK to build it itself."
