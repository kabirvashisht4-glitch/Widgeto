/// Mirrors the JSON returned by `GET /api/streak`.
///
/// The phone deliberately does no aggregation of its own — the server already
/// merged the platforms, so the app and the website always agree, and adding a
/// new connector never requires shipping an app update.
library;

class StreakSummary {
  final String timezone;
  final String today;
  final bool activeToday;
  final String status; // safe | at-risk | broken
  final int currentStreak;
  final int longestStreak;
  final int totalActiveDays;
  final int totalContributions;

  const StreakSummary({
    required this.timezone,
    required this.today,
    required this.activeToday,
    required this.status,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
    required this.totalContributions,
  });

  factory StreakSummary.fromJson(Map<String, dynamic> json) => StreakSummary(
        timezone: json['timezone'] as String? ?? 'UTC',
        today: json['today'] as String? ?? '',
        activeToday: json['activeToday'] as bool? ?? false,
        status: json['status'] as String? ?? 'broken',
        currentStreak: json['currentStreak'] as int? ?? 0,
        longestStreak: json['longestStreak'] as int? ?? 0,
        totalActiveDays: json['totalActiveDays'] as int? ?? 0,
        totalContributions: json['totalContributions'] as int? ?? 0,
      );
}

class AttributedDay {
  final String date;
  final int count;
  final Map<String, int> byPlatform;

  const AttributedDay({required this.date, required this.count, required this.byPlatform});

  factory AttributedDay.fromJson(Map<String, dynamic> json) => AttributedDay(
        date: json['date'] as String,
        count: json['count'] as int? ?? 0,
        byPlatform: (json['byPlatform'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as int)),
      );

  /// Which platform contributed most on this day — drives the square's colour.
  String? get dominantPlatform {
    if (byPlatform.isEmpty) return null;
    var best = byPlatform.entries.first;
    for (final e in byPlatform.entries) {
      if (e.value > best.value) best = e;
    }
    return best.key;
  }
}

class PlatformResult {
  final String platform;
  final String handle;
  final bool ok;
  final String? error;
  final List<({String label, String value})> stats;

  const PlatformResult({
    required this.platform,
    required this.handle,
    required this.ok,
    this.error,
    this.stats = const [],
  });

  factory PlatformResult.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final rawStats = (profile?['stats'] as List<dynamic>? ?? []);
    return PlatformResult(
      platform: json['platform'] as String,
      handle: json['handle'] as String,
      ok: json['ok'] as bool? ?? false,
      error: json['error'] as String?,
      stats: rawStats
          .map((s) => (
                label: s['label'] as String,
                value: '${s['value']}',
              ))
          .toList(),
    );
  }
}

class Activity {
  final StreakSummary summary;
  final List<AttributedDay> heatmap;
  final List<PlatformResult> platforms;

  const Activity({required this.summary, required this.heatmap, required this.platforms});

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        summary: StreakSummary.fromJson(json['summary'] as Map<String, dynamic>),
        heatmap: (json['heatmap'] as List<dynamic>)
            .map((d) => AttributedDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        platforms: (json['platforms'] as List<dynamic>)
            .map((p) => PlatformResult.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
