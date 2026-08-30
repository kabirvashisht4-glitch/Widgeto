@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgeto/data/widget_config.dart';
import 'package:widgeto/features/connect/connect_screen.dart';
import 'package:widgeto/features/gallery/gallery_screen.dart';
import 'package:widgeto/features/insights/insights_screen.dart';
import 'package:widgeto/features/studio/studio_screen.dart';
import 'package:widgeto/ui/theme.dart';
import 'package:widgeto/widgets/faces/widget_face.dart';

import 'support/sample.dart';

/// Renders the real screens to PNG, so the design can be reviewed without a
/// device and a layout regression shows up as a diff rather than as something
/// nobody noticed until it shipped.
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

Widget _app(Widget child, Brightness brightness) {
  final base = widgetoTheme(brightness);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // Pin the family for the golden only. The app deliberately leaves it unset
    // so each platform uses its own system face; a golden needs one
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

void _phone(WidgetTester tester, {double height = 2436}) {
  tester.view.physicalSize = Size(1125, height);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadRealFonts);

  testWidgets('golden: connect screen', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(
      ConnectScreen(
        initial: const {'github': 'torvalds', 'codeforces': 'tourist'},
        onDone: (_) {},
      ),
      Brightness.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(ConnectScreen),
        matchesGoldenFile('goldens/connect_screen.png'));
  });

  testWidgets('golden: gallery', (tester) async {
    _phone(tester, height: 2900);
    await tester.pumpWidget(_app(
      Scaffold(
        body: GalleryScreen(
          configs: const [
            WidgetConfig(id: '1', name: 'Everything', template: FaceTemplate.grid),
            WidgetConfig(
                id: '2',
                name: 'Just the number',
                template: FaceTemplate.minimal,
                size: FaceSize.small,
                accent: Accent.ember),
          ],
          activity: sampleActivity(),
          onEdit: (_) {},
          onCreate: () {},
          onRefresh: _noop,
        ),
      ),
      Brightness.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(GalleryScreen), matchesGoldenFile('goldens/gallery.png'));
  });

  testWidgets('golden: studio', (tester) async {
    _phone(tester, height: 3400);
    await tester.pumpWidget(_app(
      StudioScreen(
        config: const WidgetConfig(
            id: '1', name: 'Everything', template: FaceTemplate.grid),
        activity: sampleActivity(),
        connected: const ['github', 'codeforces', 'leetcode', 'atcoder'],
        onSave: (_) {},
        onDelete: () {},
      ),
      Brightness.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(StudioScreen), matchesGoldenFile('goldens/studio.png'));
  });

  testWidgets('golden: insights', (tester) async {
    _phone(tester, height: 3600);
    await tester.pumpWidget(_app(
      Scaffold(
        body: InsightsScreen(activity: sampleActivity(), onRefresh: _noop),
      ),
      Brightness.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(InsightsScreen), matchesGoldenFile('goldens/insights.png'));
  });

  // One image per layout, so a change to any template is visible in review.
  for (final template in FaceTemplate.values) {
    testWidgets('golden: ${template.label} face', (tester) async {
      // Small + medium + large stacked need more than the default surface.
      _phone(tester, height: 2400);
      await tester.pumpWidget(_app(
        Scaffold(
          backgroundColor: Skin.dark.surfaceAlt,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final size in FaceSize.values)
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: WidgetFace(
                      activity: sampleActivity(),
                      config: WidgetConfig(
                          id: 'g', template: template, size: size),
                      animate: false,
                      // Pinned so the Flame layout's "how much of today is
                      // gone" bar renders identically on every run.
                      now: DateTime(2026, 8, 28, 14, 30),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Brightness.dark,
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(Column).first,
          matchesGoldenFile('goldens/template_${template.name}.png'));
    });
  }

  testWidgets('golden: light palette', (tester) async {
    _phone(tester, height: 1800);
    await tester.pumpWidget(_app(
      Scaffold(
        backgroundColor: Skin.light.surfaceAlt,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final template in [
                FaceTemplate.grid,
                FaceTemplate.ring,
                FaceTemplate.split
              ])
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: WidgetFace(
                    activity: sampleActivity(),
                    config: WidgetConfig(
                      id: 'g',
                      template: template,
                      size: FaceSize.medium,
                      skin: WidgetSkin.light,
                      accent: Accent.ember,
                    ),
                    animate: false,
                    now: DateTime(2026, 8, 28, 14, 30),
                  ),
                ),
            ],
          ),
        ),
      ),
      Brightness.light,
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Column).first,
        matchesGoldenFile('goldens/light_palette.png'));
  });
}

Future<void> _noop() async {}
