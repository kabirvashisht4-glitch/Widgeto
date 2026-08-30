import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgeto/data/insights.dart';
import 'package:widgeto/data/models.dart';
import 'package:widgeto/data/streak.dart';
import 'package:widgeto/data/widget_config.dart';
import 'package:widgeto/features/connect/connect_screen.dart';
import 'package:widgeto/features/gallery/gallery_screen.dart';
import 'package:widgeto/features/studio/studio_screen.dart';
import 'package:widgeto/main.dart';
import 'package:widgeto/ui/theme.dart';
import 'package:widgeto/widgets/contribution_grid.dart';
import 'package:widgeto/widgets/faces/widget_face.dart';

import 'support/sample.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('first run', () {
    testWidgets('lands on the connect wall, not a form', (tester) async {
      await tester.pumpWidget(const WidgetoApp());
      await tester.pumpAndSettle();

      expect(find.text('Where do you\ncode?'), findsOneWidget);
      for (final mark in ['GH', 'CF', 'LC', 'AC']) {
        expect(find.text(mark), findsOneWidget);
      }
      expect(find.text('tap to add'), findsNWidgets(4));
    });

    testWidgets('cannot continue with nothing connected', (tester) async {
      await tester.pumpWidget(const WidgetoApp());
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('connect screen', () {
    testWidgets('a saved handle shows on its tile and unlocks the button',
        (tester) async {
      Map<String, String>? submitted;
      await tester.pumpWidget(MaterialApp(
        theme: widgetoTheme(Brightness.dark),
        home: ConnectScreen(
          initial: const {'github': 'torvalds'},
          onDone: (h) => submitted = h,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('torvalds'), findsOneWidget);
      expect(find.text('Build my streak  ·  1 connected'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(submitted, {'github': 'torvalds'});
    });

    testWidgets('as a tab it reframes itself rather than repeating onboarding',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: widgetoTheme(Brightness.dark),
        home: ConnectScreen(
          initial: const {'github': 'torvalds'},
          embedded: true,
          onDone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your platforms'), findsOneWidget);
      expect(find.text('Save  ·  1 connected'), findsOneWidget);
    });

    testWidgets('tapping a tile opens a sheet that never asks for a password',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: widgetoTheme(Brightness.dark),
        home: ConnectScreen(initial: const {}, onDone: (_) {}),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Codeforces'));
      await tester.pumpAndSettle();

      expect(find.text('Your public username. No password, ever.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('widget faces', () {
    testWidgets('every template renders at every size in both palettes',
        (tester) async {
      // 6 templates × 3 sizes × 2 palettes. Layout bugs hide in exactly the
      // combination nobody thought to open.
      for (final template in FaceTemplate.values) {
        for (final size in FaceSize.values) {
          for (final skin in [WidgetSkin.dark, WidgetSkin.light]) {
            await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                body: Center(
                  child: WidgetFace(
                    activity: sampleActivity(),
                    config: WidgetConfig(
                      id: 't',
                      template: template,
                      size: size,
                      skin: skin,
                    ),
                    animate: false,
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${template.label} · ${size.label} · ${skin.name}');
          }
        }
      }
    });

    testWidgets('the streak reads the same across templates', (tester) async {
      for (final template in [FaceTemplate.grid, FaceTemplate.minimal, FaceTemplate.ring]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: WidgetFace(
              activity: sampleActivity(),
              config: WidgetConfig(id: 't', template: template, size: FaceSize.large),
              animate: false,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('59'), findsOneWidget, reason: template.label);
      }
    });

    testWidgets('the Flame bar tracks the injected clock, not the wall clock',
        (tester) async {
      Future<double> barAt(DateTime when) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: WidgetFace(
                activity: sampleActivity(),
                config: const WidgetConfig(
                    id: 'f', template: FaceTemplate.flame, size: FaceSize.medium),
                animate: false,
                now: when,
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        return tester
            .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
            .value!;
      }

      // A golden that reads the real clock drifts every hour and fails for
      // reasons unrelated to the code.
      expect(await barAt(DateTime(2026, 8, 28, 6, 0)), closeTo(0.25, 0.01));
      expect(await barAt(DateTime(2026, 8, 28, 18, 0)), closeTo(0.75, 0.01));
    });

    testWidgets('the split bar actually has area', (tester) async {
      // A childless ColoredBox takes the smallest height offered, so this bar
      // once rendered at full width and zero height — present in the tree,
      // invisible on screen, and passing every test that only asked whether it
      // existed.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: WidgetFace(
              activity: sampleActivity(),
              config: const WidgetConfig(
                  id: 's', template: FaceTemplate.split, size: FaceSize.medium),
              animate: false,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final segments = find.byType(ColoredBox).evaluate().where((e) {
        final box = e.renderObject as RenderBox;
        return box.size.width > 0 && box.size.width < 400;
      });

      expect(segments, isNotEmpty, reason: 'the bar should have segments');
      for (final segment in segments) {
        expect((segment.renderObject as RenderBox).size.height, greaterThan(0),
            reason: 'a zero-height segment is an invisible bar');
      }
    });

    testWidgets('a broken streak turns the number red on any template',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WidgetFace(
            activity: sampleActivity(status: 'broken', streak: 0),
            config: const WidgetConfig(id: 't', template: FaceTemplate.minimal),
            animate: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('0'));
      expect(text.style?.color, kDanger,
          reason: 'a broken streak overrides the chosen accent');
    });
  });

  group('scoping a widget to some platforms', () {
    test('an empty set means everything, so new platforms join automatically', () {
      final all = ScopedActivity.scoped(sampleActivity(), const <String>{});
      expect(all.summary.currentStreak, sampleActivity().summary.currentStreak);
      expect(all.platforms.length, 4);
    });

    test('narrowing drops the other platforms and recomputes the streak', () {
      final activity = Activity.fromJson({
        'summary': summaryJson(status: 'safe', streak: 3, today: '2026-08-28'),
        'heatmap': [
          {'date': '2026-08-26', 'count': 2, 'byPlatform': {'github': 2}},
          {'date': '2026-08-27', 'count': 3, 'byPlatform': {'leetcode': 3}},
          {'date': '2026-08-28', 'count': 1, 'byPlatform': {'github': 1}},
        ],
        'platforms': [
          {'platform': 'github', 'handle': 'a', 'ok': true},
          {'platform': 'leetcode', 'handle': 'b', 'ok': true},
        ],
      });

      // GitHub alone: the 27th was LeetCode only, so the run breaks there and
      // today stands alone.
      final github = ScopedActivity.scoped(activity, {'github'});
      expect(github.summary.currentStreak, 1);
      expect(github.summary.totalContributions, 3);
      expect(github.platforms.single.platform, 'github');

      // Together the three days are consecutive.
      final both = ScopedActivity.scoped(activity, {'github', 'leetcode'});
      expect(both.summary.currentStreak, 3);
    });

    test('an empty today is pending, exactly as on the server', () {
      final activity = Activity.fromJson({
        'summary': summaryJson(status: 'at-risk', streak: 2, today: '2026-08-28'),
        'heatmap': [
          {'date': '2026-08-26', 'count': 1, 'byPlatform': {'github': 1}},
          {'date': '2026-08-27', 'count': 1, 'byPlatform': {'github': 1}},
          {'date': '2026-08-28', 'count': 0, 'byPlatform': <String, int>{}},
        ],
        'platforms': [
          {'platform': 'github', 'handle': 'a', 'ok': true},
        ],
      });

      final scoped = ScopedActivity.scoped(activity, {'github'});
      expect(scoped.summary.status, 'at-risk');
      expect(scoped.summary.currentStreak, 2, reason: 'the day is not over');
    });
  });

  group('widget config', () {
    test('survives a round trip through storage', () {
      const config = WidgetConfig(
        id: 'x',
        name: 'Work only',
        template: FaceTemplate.ring,
        size: FaceSize.large,
        skin: WidgetSkin.light,
        accent: Accent.violet,
        platforms: {'github'},
        showCaption: false,
      );
      expect(WidgetConfig.fromJson(config.toJson()), config);
    });

    test('an unknown value falls back instead of losing the widget', () {
      final config = WidgetConfig.fromJson(const {
        'id': 'x',
        'template': 'from-a-newer-build',
        'size': 'enormous',
        'accent': 'chartreuse',
      });
      expect(config.template, FaceTemplate.grid);
      expect(config.size, FaceSize.medium);
      expect(config.accent, Accent.flame);
    });

    test('includes() treats an empty set as everything', () {
      const all = WidgetConfig(id: 'x');
      expect(all.includes('atcoder'), isTrue);
      const some = WidgetConfig(id: 'x', platforms: {'github'});
      expect(some.includes('github'), isTrue);
      expect(some.includes('atcoder'), isFalse);
    });

    test('a corrupt store still yields a usable widget', () async {
      SharedPreferences.setMockInitialValues({'widget_configs': 'not json'});
      final configs = await WidgetStore.load();
      expect(configs, hasLength(1));
    });
  });

  group('insights', () {
    test('momentum compares the last week with the one before', () {
      final heatmap = [
        for (var i = 0; i < 14; i++)
          AttributedDay(
            date: '2026-08-${(i + 10).toString().padLeft(2, '0')}',
            // 2/day in the older week, 5/day in the recent one.
            count: i < 7 ? 2 : 5,
            byPlatform: {'github': i < 7 ? 2 : 5},
          ),
      ];
      final insights = Insights.from(
          heatmap, StreakSummary.fromJson(summaryJson(streak: 14)));

      expect(insights.last7, 35);
      expect(insights.prev7, 14);
      expect(insights.momentum, closeTo(150, 0.01));
    });

    test('the next milestone is always ahead of the current streak', () {
      for (final streak in [0, 6, 7, 29, 99, 400, 1200]) {
        final insights = Insights.from(
            const [], StreakSummary.fromJson(summaryJson(streak: streak)));
        expect(insights.nextMilestone, greaterThan(streak),
            reason: 'streak $streak');
      }
    });

    test('platform split sums to one', () {
      final insights = Insights.from(
        sampleActivity().heatmap,
        sampleActivity().summary,
      );
      final total = insights.byPlatform.fold(0.0, (a, r) => a + r.share);
      expect(total, closeTo(1.0, 0.001));
      expect(insights.byPlatform.first.count,
          greaterThanOrEqualTo(insights.byPlatform.last.count),
          reason: 'sorted descending');
    });
  });

  group('contribution grid', () {
    testWidgets('an empty grid renders nothing rather than throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ContributionGrid(days: []))),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('replay restarts the reveal', (tester) async {
      final key = GlobalKey<ContributionGridState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ContributionGrid(key: key, days: sampleActivity().heatmap)),
      ));
      await tester.pumpAndSettle();

      key.currentState!.replay();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets("the builder's controls are operable by a screen reader",
        (tester) async {
      final handle = tester.ensureSemantics();
      // The studio is a ListView; on the default 600px surface the size,
      // palette and source controls are never built, so they cannot be found.
      tester.view.physicalSize = const Size(1125, 3400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: widgetoTheme(Brightness.dark),
        home: StudioScreen(
          config: const WidgetConfig(id: '1', template: FaceTemplate.grid),
          activity: sampleActivity(),
          connected: const ['github', 'codeforces'],
          onSave: (_) {},
          onDelete: null,
        ),
      ));
      await tester.pumpAndSettle();

      // Layout cards, size and palette segments and source chips are all
      // GestureDetectors — without explicit semantics they are invisible to
      // assistive tech, which is most of the editor being unusable.
      expect(
        find.bySemanticsLabel(RegExp('^Grid layout')),
        findsOneWidget,
        reason: 'each layout announces itself and what it shows',
      );
      // Segments carry no label of their own — the visible word names them,
      // and a wrapper label would be announced twice.
      expect(find.bySemanticsLabel('Medium'), findsOneWidget);
      expect(find.bySemanticsLabel('Dark'), findsOneWidget);
      expect(find.bySemanticsLabel('GitHub as a source'), findsOneWidget);

      // Nothing should announce its own name twice.
      for (final label in ['Grid layout. The contribution calendar, blended by platform',
                           'GitHub as a source']) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(node.label, label, reason: 'label must not be doubled');
      }

      // The selected layout must report that it is selected, or a screen
      // reader user cannot tell which one is active.
      //
      // hasFlag is deprecated in favour of the isSemantics matcher, but that
      // matcher throws while building its own mismatch description, so it
      // cannot report a failure. A deprecated call that works beats a
      // replacement that cannot.
      // ignore: deprecated_member_use
      bool isSelectedNode(Finder f) => tester
          .getSemantics(f)
          // ignore: deprecated_member_use
          .hasFlag(SemanticsFlag.isSelected);

      expect(isSelectedNode(find.bySemanticsLabel(RegExp('^Grid layout'))), isTrue);
      expect(isSelectedNode(find.bySemanticsLabel(RegExp('^Flame layout'))), isFalse);

      handle.dispose();
    });

    testWidgets('gallery cards say which widget they open', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(MaterialApp(
        theme: widgetoTheme(Brightness.dark),
        home: Scaffold(
          body: GalleryScreen(
            configs: const [
              WidgetConfig(
                  id: '1', name: 'Work only', template: FaceTemplate.ring),
            ],
            activity: sampleActivity(),
            onEdit: (_) {},
            onCreate: () {},
            onRefresh: _noRefresh,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('Edit Work only')), findsOneWidget);
      handle.dispose();
    });
  });

  group('palette', () {
    test('every platform has its own colour, label and mark', () {
      const platforms = ['github', 'codeforces', 'leetcode', 'atcoder'];
      expect(platforms.map(platformColor).toSet(), hasLength(platforms.length));
      for (final p in platforms) {
        expect(platformLabel(p), isNot(p));
        expect(platformMark(p).length, 2);
      }
    });

    test('accents are distinct', () {
      expect(Accent.values.map((a) => a.color).toSet(),
          hasLength(Accent.values.length));
    });
  });
}

Future<void> _noRefresh() async {}
