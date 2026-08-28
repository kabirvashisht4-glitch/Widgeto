import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgeto/data/models.dart';
import 'package:widgeto/features/connect/connect_screen.dart';
import 'package:widgeto/main.dart';
import 'package:widgeto/ui/theme.dart';
import 'package:widgeto/widgets/contribution_grid.dart';
import 'package:widgeto/widgets/widget_face.dart';

Activity _sample({String status = 'at-risk', int streak = 59}) => Activity.fromJson({
      'summary': {
        'timezone': 'Asia/Kolkata',
        'today': '2026-08-28',
        'activeToday': status == 'safe',
        'status': status,
        'currentStreak': streak,
        'longestStreak': 80,
        'totalActiveDays': 355,
        'totalContributions': 4032,
      },
      'heatmap': [
        for (var i = 1; i <= 28; i++)
          {
            'date': '2026-08-${i.toString().padLeft(2, '0')}',
            'count': i % 4,
            'byPlatform': i % 4 == 0 ? {} : {'github': i % 4},
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
            ],
          },
        },
      ],
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('first run', () {
    testWidgets('lands on the connect wall, not a form', (tester) async {
      await tester.pumpWidget(const WidgetoApp());
      await tester.pumpAndSettle();

      expect(find.text('Where do you\ncode?'), findsOneWidget);
      // One tile per platform, each showing its own mark.
      for (final mark in ['GH', 'CF', 'LC', 'AC']) {
        expect(find.text(mark), findsOneWidget);
      }
      expect(find.text('tap to add'), findsNWidgets(4));
    });

    testWidgets('cannot continue with nothing connected', (tester) async {
      await tester.pumpWidget(const WidgetoApp());
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: 'nothing to merge yet');
      expect(find.text('Add at least one'), findsOneWidget);
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

  group('widget face', () {
    testWidgets('renders the streak and its status', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WidgetFace(
            activity: _sample(),
            size: FaceSize.medium,
            skin: Skin.dark,
            animate: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('59'), findsOneWidget);
      expect(find.text('not yet today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a broken streak says so', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WidgetFace(
            activity: _sample(status: 'broken', streak: 0),
            size: FaceSize.small,
            skin: Skin.light,
            animate: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('streak broken'), findsOneWidget);
    });

    testWidgets('every size renders in both palettes', (tester) async {
      for (final size in FaceSize.values) {
        for (final skin in [Skin.dark, Skin.light]) {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: WidgetFace(
                activity: _sample(),
                size: size,
                skin: skin,
                animate: false,
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${size.label} in ${skin == Skin.dark ? 'dark' : 'light'}');
        }
      }
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

    testWidgets('replay restarts the reveal without rebuilding', (tester) async {
      final key = GlobalKey<ContributionGridState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ContributionGrid(key: key, days: _sample().heatmap)),
      ));
      await tester.pumpAndSettle();

      key.currentState!.replay();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('models', () {
    test('dominant platform picks the busiest source for the day', () {
      const day = AttributedDay(
        date: '2026-08-28',
        count: 9,
        byPlatform: {'github': 2, 'leetcode': 7},
      );
      expect(day.dominantPlatform, 'leetcode');
    });

    test('a quiet day has no dominant platform', () {
      const day = AttributedDay(date: '2026-08-28', count: 0, byPlatform: {});
      expect(day.dominantPlatform, isNull);
    });

    test('a failed platform survives parsing so the UI can show why', () {
      final activity = Activity.fromJson({
        'summary': {
          'timezone': 'UTC',
          'today': '2026-08-28',
          'activeToday': false,
          'status': 'broken',
          'currentStreak': 0,
          'longestStreak': 0,
          'totalActiveDays': 0,
          'totalContributions': 0,
        },
        'heatmap': const [],
        'platforms': [
          {
            'platform': 'leetcode',
            'handle': 'nobody',
            'ok': false,
            'error': 'no LeetCode user named "nobody"',
          },
        ],
      });
      expect(activity.platforms.single.ok, isFalse);
      expect(activity.platforms.single.error, contains('nobody'));
    });
  });

  group('palette', () {
    test('every platform has its own colour and label', () {
      const platforms = ['github', 'codeforces', 'leetcode', 'atcoder'];
      final colors = platforms.map(platformColor).toSet();
      expect(colors.length, platforms.length, reason: 'colours must be distinct');
      for (final p in platforms) {
        expect(platformLabel(p), isNot(p), reason: '$p needs a display name');
        expect(platformMark(p).length, 2);
      }
    });
  });
}
