import 'package:widgeto/data/models.dart';

/// Shared fixture. A year that actually mixes platforms, so blending, splits
/// and per-platform scoping all have something real to work on.
Map<String, dynamic> summaryJson({
  String status = 'at-risk',
  int streak = 59,
  String today = '2026-08-28',
}) =>
    {
      'timezone': 'Asia/Kolkata',
      'today': today,
      'activeToday': status == 'safe',
      'status': status,
      'currentStreak': streak,
      'longestStreak': 80,
      'totalActiveDays': 355,
      'totalContributions': 4032,
    };

Activity sampleActivity({String status = 'at-risk', int streak = 59}) =>
    Activity.fromJson({
      'summary': summaryJson(status: status, streak: streak),
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
