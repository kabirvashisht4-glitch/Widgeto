import 'models.dart';

/// Recomputing a streak on the phone, for a subset of platforms.
///
/// The server already merged everything the user connected. But a widget can
/// be scoped to some of those platforms — "GitHub only" on one widget, all
/// four on another — and that scoped streak is a different number. Asking the
/// server per widget would multiply requests for something derivable from the
/// day data already in hand, so it is derived here.
///
/// The rules match the server exactly, including the one that matters most:
/// an empty today is *pending*, not a broken streak. The day is not over.
class ScopedActivity {
  const ScopedActivity({
    required this.summary,
    required this.heatmap,
    required this.platforms,
  });

  final StreakSummary summary;
  final List<AttributedDay> heatmap;
  final List<PlatformResult> platforms;

  /// Everything, unscoped — the server's own answer.
  factory ScopedActivity.all(Activity activity) => ScopedActivity(
        summary: activity.summary,
        heatmap: activity.heatmap,
        platforms: activity.platforms,
      );

  /// Narrow to `keep`. An empty set means "everything", so a platform the user
  /// connects later joins existing widgets instead of being left out.
  factory ScopedActivity.scoped(Activity activity, Set<String> keep) {
    if (keep.isEmpty) return ScopedActivity.all(activity);

    final heatmap = activity.heatmap.map((d) {
      final kept = <String, int>{
        for (final e in d.byPlatform.entries)
          if (keep.contains(e.key)) e.key: e.value,
      };
      return AttributedDay(
        date: d.date,
        count: kept.values.fold(0, (a, b) => a + b),
        byPlatform: kept,
      );
    }).toList();

    return ScopedActivity(
      summary: _recompute(heatmap, activity.summary),
      heatmap: heatmap,
      platforms:
          activity.platforms.where((p) => keep.contains(p.platform)).toList(),
    );
  }

  static StreakSummary _recompute(
    List<AttributedDay> heatmap,
    StreakSummary original,
  ) {
    final active = <String>{
      for (final d in heatmap)
        if (d.count > 0) d.date,
    };

    final today = original.today;
    final activeToday = active.contains(today);

    // Walk back from today if it counts, otherwise from yesterday — today is
    // still open, so an empty one must not end the run.
    var cursor = activeToday ? today : _shift(today, -1);
    var current = 0;
    while (active.contains(cursor)) {
      current++;
      cursor = _shift(cursor, -1);
    }

    final sorted = active.toList()..sort();
    var longest = 0;
    var run = 0;
    String? previous;
    for (final date in sorted) {
      run = (previous != null && _shift(previous, 1) == date) ? run + 1 : 1;
      if (run > longest) longest = run;
      previous = date;
    }

    return StreakSummary(
      timezone: original.timezone,
      today: today,
      activeToday: activeToday,
      status: activeToday ? 'safe' : (current > 0 ? 'at-risk' : 'broken'),
      currentStreak: current,
      longestStreak: longest,
      totalActiveDays: active.length,
      totalContributions: heatmap.fold(0, (sum, d) => sum + d.count),
    );
  }

  /// Shift a `YYYY-MM-DD` by whole days, anchored at UTC noon so a daylight
  /// saving transition can never swallow or duplicate a day.
  static String _shift(String date, int days) {
    final parts = date.split('-').map(int.parse).toList();
    final anchor = DateTime.utc(parts[0], parts[1], parts[2], 12);
    final moved = anchor.add(Duration(days: days));
    return '${moved.year.toString().padLeft(4, '0')}-'
        '${moved.month.toString().padLeft(2, '0')}-'
        '${moved.day.toString().padLeft(2, '0')}';
  }
}
