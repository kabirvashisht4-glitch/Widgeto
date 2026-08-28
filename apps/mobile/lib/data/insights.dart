import 'models.dart';

/// The things a streak number alone cannot tell you.
///
/// A widget answers "am I safe today". The app should answer the questions you
/// only ask once you care: is this getting better or worse, when do I actually
/// work, and how far is the next number worth bragging about.
class Insights {
  const Insights({
    required this.last7,
    required this.prev7,
    required this.bestWeekday,
    required this.bestWeekdayCount,
    required this.nextMilestone,
    required this.byPlatform,
    required this.busiestDay,
    required this.busiestDayCount,
  });

  /// Contributions in the last 7 days, and the 7 before that.
  final int last7;
  final int prev7;

  /// 1 = Monday … 7 = Sunday, matching DateTime.weekday.
  final int bestWeekday;
  final int bestWeekdayCount;

  /// The next round streak worth chasing.
  final int nextMilestone;

  /// Share of total contributions per platform, descending.
  final List<({String platform, int count, double share})> byPlatform;

  final String? busiestDay;
  final int busiestDayCount;

  /// Percentage change week over week; null when there is no earlier week to
  /// compare against, which is different from "no change".
  double? get momentum {
    if (prev7 == 0) return last7 > 0 ? null : 0;
    return (last7 - prev7) / prev7 * 100;
  }

  int daysToMilestone(int currentStreak) => nextMilestone - currentStreak;

  static const _milestones = [7, 14, 30, 50, 100, 150, 200, 250, 365, 500, 730, 1000];

  factory Insights.from(List<AttributedDay> heatmap, StreakSummary summary) {
    var last7 = 0;
    var prev7 = 0;
    final tail = heatmap.length;
    for (var i = 0; i < heatmap.length; i++) {
      final fromEnd = tail - 1 - i;
      if (fromEnd < 7) {
        last7 += heatmap[i].count;
      } else if (fromEnd < 14) {
        prev7 += heatmap[i].count;
      }
    }

    final perWeekday = List<int>.filled(8, 0);
    final perPlatform = <String, int>{};
    String? busiestDay;
    var busiestCount = 0;

    for (final day in heatmap) {
      if (day.count <= 0) continue;
      perWeekday[DateTime.parse(day.date).weekday] += day.count;
      day.byPlatform.forEach((platform, count) {
        perPlatform[platform] = (perPlatform[platform] ?? 0) + count;
      });
      if (day.count > busiestCount) {
        busiestCount = day.count;
        busiestDay = day.date;
      }
    }

    var bestWeekday = 1;
    for (var d = 1; d <= 7; d++) {
      if (perWeekday[d] > perWeekday[bestWeekday]) bestWeekday = d;
    }

    final total = perPlatform.values.fold(0, (a, b) => a + b);
    final byPlatform = perPlatform.entries
        .map((e) => (
              platform: e.key,
              count: e.value,
              share: total == 0 ? 0.0 : e.value / total,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final next = _milestones.firstWhere(
      (m) => m > summary.currentStreak,
      // Past every named milestone, the next round hundred still works.
      orElse: () => ((summary.currentStreak ~/ 500) + 1) * 500,
    );

    return Insights(
      last7: last7,
      prev7: prev7,
      bestWeekday: bestWeekday,
      bestWeekdayCount: perWeekday[bestWeekday],
      nextMilestone: next,
      byPlatform: byPlatform,
      busiestDay: busiestDay,
      busiestDayCount: busiestCount,
    );
  }

  static const weekdayNames = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
}
