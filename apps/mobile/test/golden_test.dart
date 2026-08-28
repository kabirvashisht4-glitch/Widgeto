@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgeto/data/models.dart';
import 'package:widgeto/features/connect/connect_screen.dart';
import 'package:widgeto/features/preview/preview_screen.dart';
import 'package:widgeto/ui/theme.dart';
import 'package:widgeto/widgets/widget_face.dart';

/// Renders the real screens to PNG, so the app's look can be reviewed without
/// a device — and so an accidental layout regression shows up as a diff rather
/// than as something nobody noticed until it shipped.
///
/// Regenerate with:  flutter test --update-goldens test/golden_test.dart

/// The test environment ships a font whose every glyph is a box, which makes a
/// golden useless for judging a design. Loading the SDK's real Roboto fixes it.
Future<void> _loadRealFonts() async {
  const dir = '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;

  for (final entry in {
    'Roboto': ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
    // Without this every Icon renders as an opaque box.
    'MaterialIcons': ['MaterialIcons-Regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final f = File('$dir/$file');
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
    }
    await loader.load();
  }
}

Activity _activity() => Activity.fromJson({
      'summary': {
        'timezone': 'Asia/Kolkata',
        'today': '2026-08-28',
        'activeToday': false,
        'status': 'at-risk',
        'currentStreak': 59,
        'longestStreak': 80,
        'totalActiveDays': 355,
        'totalContributions': 4032,
      },
      // A year that actually mixes platforms, so the blend is visible.
      'heatmap': [
        for (var i = 0; i < 365; i++)
          {
            'date': DateTime(2025, 8, 29)
                .add(Duration(days: i))
                .toIso8601String()
                .substring(0, 10),
            'count': [0, 3, 7, 2, 11, 0, 5, 9][i % 8],
            'byPlatform': switch (i % 7) {
              0 => <String, int>{},
              1 => {'github': 6},
              2 => {'leetcode': 4},
              3 => {'github': 5, 'leetcode': 3},
              4 => {'codeforces': 7},
              5 => {'github': 9, 'atcoder': 2},
              _ => {'github': 3, 'codeforces': 2, 'leetcode': 4},
            },
          },
      ],
      'platforms': [
        {
          'platform': 'github',
          'handle': 'torvalds',
          'ok': true,
          'profile': {
            'stats': [
              {'label': 'contributions', 'value': 3595},
              {'label': 'stars', 'value': 256566},
              {'label': 'followers', 'value': 318551},
            ],
          },
        },
        {
          'platform': 'codeforces',
          'handle': 'tourist',
          'ok': true,
          'profile': {
            'stats': [
              {'label': 'rating', 'value': 3528},
              {'label': 'peak', 'value': 4009},
              {'label': 'solved', 'value': 171},
            ],
          },
        },
        {
          'platform': 'leetcode',
          'handle': 'lee215',
          'ok': true,
          'profile': {
            'stats': [
              {'label': 'solved', 'value': 668},
              {'label': 'medium', 'value': 400},
              {'label': 'hard', 'value': 144},
            ],
          },
        },
        {
          'platform': 'atcoder',
          'handle': 'tourist',
          'ok': true,
          'profile': {
            'stats': [
              {'label': 'solved', 'value': 1057},
              {'label': 'rank', 'value': '#4,414'},
            ],
          },
        },
      ],
    });

Widget _phone(Widget child, Brightness brightness) {
  final base = widgetoTheme(brightness);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // Pin the family for the golden only. The app deliberately leaves it
    // unset so each platform uses its own system face; a golden needs one
    // deterministic font or the image changes with the host.
    theme: base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
      // Button labels take their style from the button theme, not from
      // DefaultTextStyle, so they need pinning separately.
      filledButtonTheme: FilledButtonThemeData(
        style: (base.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: 'Roboto', fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ),
    builder: (context, child) => DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Roboto'),
      child: child!,
    ),
    home: child,
  );
}

void main() {
  setUpAll(_loadRealFonts);

  testWidgets('golden: connect screen', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_phone(
      ConnectScreen(
        initial: const {'github': 'torvalds', 'codeforces': 'tourist'},
        onDone: (_) {},
      ),
      Brightness.dark,
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ConnectScreen),
      matchesGoldenFile('goldens/connect_screen.png'),
    );
  });

  testWidgets('golden: preview screen', (tester) async {
    tester.view.physicalSize = const Size(1125, 2900);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_phone(
      PreviewScreen(
        activity: _activity(),
        refreshing: false,
        onRefresh: () async {},
        onEditHandles: () {},
      ),
      Brightness.dark,
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PreviewScreen),
      matchesGoldenFile('goldens/preview_screen.png'),
    );
  });

  for (final size in FaceSize.values) {
    for (final entry in {'dark': Skin.dark, 'light': Skin.light}.entries) {
      testWidgets('golden: ${size.label} face, ${entry.key}', (tester) async {
        await tester.pumpWidget(_phone(
          Scaffold(
            backgroundColor: entry.value.surfaceAlt,
            body: Center(
              child: WidgetFace(
                activity: _activity(),
                size: size,
                skin: entry.value,
                animate: false,
              ),
            ),
          ),
          Brightness.dark,
        ));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(WidgetFace),
          matchesGoldenFile(
              'goldens/face_${size.name}_${entry.key}.png'),
        );
      });
    }
  }
}
