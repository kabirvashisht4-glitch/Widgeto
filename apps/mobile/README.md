# Widgeto — mobile

Flutter app + native home-screen widget faces.

> **Status.** The Flutter app is built and tested: the analyzer is clean, 37
> tests and 11 goldens pass, and it ships as an installable PWA served at
> `/app` — which is how you run Widgeto without Xcode or the Android SDK.
>
> The **native widget faces** (`ios/`, `android/`) are the part still unproven.
> They are written but have never been compiled, because producing an `.ipa` or
> `.apk` needs Xcode and the Android SDK. The setup below is what they need.

## Running it without a native toolchain

```bash
../../scripts/build-app.sh   # builds into apps/web/public/app
npm run dev --workspace @widgeto/web
```

Then open `/app` and use *Add to Home Screen* (iOS) or *Install app*
(Android). It runs full-screen, works offline, and talks to the API on the same
origin — no configuration.

This gets you the app. It does **not** get you a home-screen *widget*: the OS
only renders those from a signed native build.

## Why Flutter plus native

Home-screen widgets cannot be drawn by Flutter. iOS requires a WidgetKit
extension in SwiftUI and Android requires Glance or RemoteViews, both running
in a separate process from your app. So:

| Layer | Owner |
|---|---|
| App UI (setup, preview) | Flutter — `lib/` |
| iOS widget face | SwiftUI — `ios/WidgetoWidget/` |
| Android widget face | Kotlin — `android/.../StreakWidgetReceiver.kt` |
| Data across the boundary | `home_widget` package |

**The widget faces never fetch and never compute.** The Flutter app calls
`/api/streak`, encodes a finished payload, and writes it to the shared
container; the native side reads and draws. Widget extensions run under a hard
memory cap and can be killed for exceeding it, so a dumb renderer is the only
design that stays reliable.

## Generating the platform scaffolding

Only `lib/`, the Swift widget and the Kotlin widget are committed here — the
generated Xcode and Gradle projects are not. To produce them:

```bash
cd apps/mobile && flutter create --org me.widgeto --platforms=ios,android .
```

That leaves the committed `lib/` and native widget sources untouched and fills
in everything around them. Then:

```bash
flutter pub get
flutter run
```

## iOS widget setup (one-time, in Xcode)

1. `open ios/Runner.xcworkspace`
2. **File → New → Target → Widget Extension**, name it exactly `WidgetoWidget`.
   Uncheck "Include Configuration Intent".
3. Replace the generated Swift with `ios/WidgetoWidget/WidgetoWidget.swift`.
4. Add the **App Groups** capability to *both* the `Runner` and `WidgetoWidget`
   targets, using the identical group id:

   ```
   group.me.widgeto.shared
   ```

   This must match `WidgetBridge.iosAppGroup` in `lib/data/widget_bridge.dart`
   and `appGroup` in the Swift file. A mismatch here is the single most common
   cause of a widget that renders zeros forever — the extension is reading a
   container the app never wrote to.

## Android widget setup

`flutter create` generates the manifest; add the receiver and a
`streak_widget` layout containing `widget_root`, `streak_value`,
`streak_status` and `streak_grid` (an `ImageView`).

## The refresh budget

iOS grants a widget only a few dozen timeline refreshes per day, and the system
decides when. The provider therefore asks for 60-minute refreshes normally and
30 when the streak is at risk, rather than requesting more than it can get.

This is also why the streak must never read as broken just because the widget
is stale: the engine treats an empty today as `at-risk`, not `broken`, so a
missed refresh can never wrongly tell someone their run ended.
