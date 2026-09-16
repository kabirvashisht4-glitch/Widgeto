#!/usr/bin/env bash
# Build the Flutter app as an installable PWA and place it inside the website,
# so a single deploy serves the site, the API and the app together.
#
# This is what makes Widgeto usable without Xcode or the Android SDK: the app
# is installed from the browser's "Add to Home Screen".
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/apps/web/public/app"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found — skipping the app build."
  echo "The website and API build fine without it; install Flutter to include the app."
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

echo "App built into apps/web/public/app — served at /app"
