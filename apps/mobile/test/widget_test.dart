import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgeto/main.dart';
import 'package:widgeto/data/models.dart';
import 'package:widgeto/ui/grid.dart';

void main() {
  testWidgets('app boots to the handle form', (tester) async {
    await tester.pumpWidget(const WidgetoApp());
    await tester.pump();

    expect(find.text('Widgeto'), findsOneWidget);
    expect(find.text('Handles'), findsOneWidget);
    expect(find.text('Update my widget'), findsOneWidget);
    // One field per connected platform.
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('asking for a streak with no handles explains why, not nothing',
      (tester) async {
    await tester.pumpWidget(const WidgetoApp());
    await tester.pump();

    await tester.tap(find.text('Update my widget'));
    await tester.pump();

    expect(find.text('Add at least one handle.'), findsOneWidget);
  });

  testWidgets('an empty grid renders nothing rather than throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ContributionGrid(days: []))),
    );
    expect(tester.takeException(), isNull);
  });

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

  test('models survive the JSON the API actually returns', () {
    final activity = Activity.fromJson({
      'summary': {
        'timezone': 'Asia/Kolkata',
        'today': '2026-08-28',
        'activeToday': true,
        'status': 'safe',
        'currentStreak': 59,
        'longestStreak': 80,
        'totalActiveDays': 355,
        'totalContributions': 4032,
      },
      'heatmap': [
        {'date': '2026-08-28', 'count': 5, 'byPlatform': {'github': 5}},
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
        {
          'platform': 'leetcode',
          'handle': 'nobody',
          'ok': false,
          'error': 'no LeetCode user named "nobody"',
        },
      ],
    });

    expect(activity.summary.currentStreak, 59);
    expect(activity.heatmap.single.byPlatform['github'], 5);
    expect(activity.platforms.first.stats.first.value, '3595');
    // A failed platform must survive parsing so the UI can show the reason.
    expect(activity.platforms.last.ok, isFalse);
    expect(activity.platforms.last.error, contains('nobody'));
  });
}
