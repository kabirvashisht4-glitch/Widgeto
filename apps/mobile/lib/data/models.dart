/// Mirrors the JSON returned by `GET /api/streak`.
///
/// The phone deliberately does no aggregation of its own — the server already
/// merged the platforms, so the app and the website always agree, and adding a
/// new connector never requires shipping an app update.
library;

/// Numbers can arrive as int or double depending on the encoder; neither
/// should be able to crash a widget over a rounding detail.
int _int(Object? v) => v is num ? v.round() : 0;

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
        activeToday: json['activeToday'] == true,
        status: json['status'] as String? ?? 'broken',
        currentStreak: _int(json['currentStreak']),
        longestStreak: _int(json['longestStreak']),
        totalActiveDays: _int(json['totalActiveDays']),
        totalContributions: _int(json['totalContributions']),
      );
}

class AttributedDay {
  final String date;
  final int count;
  final Map<String, int> byPlatform;

  const AttributedDay({required this.date, required this.count, required this.byPlatform});

  factory AttributedDay.fromJson(Map<String, dynamic> json) => AttributedDay(
        date: json['date'] as String,
        count: _int(json['count']),
        // Map.from rather than a cast: a nested map arriving from jsonDecode is
        // Map<String, dynamic>, but the same literal written in Dart is
        // Map<dynamic, dynamic>, and a hard cast throws on the second.
        byPlatform: Map<String, dynamic>.from(json['byPlatform'] as Map? ?? {})
            .map((k, v) => MapEntry(k, _int(v))),
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
    final profile = json['profile'] as Map?;
    final rawStats = (profile?['stats'] as List? ?? const []);
    return PlatformResult(
      platform: json['platform'] as String,
      handle: json['handle'] as String,
      ok: json['ok'] == true,
      error: json['error'] as String?,
      stats: rawStats
          .map((s) => (
                label: '${(s as Map)['label']}',
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
        summary: StreakSummary.fromJson(
            Map<String, dynamic>.from(json['summary'] as Map)),
        heatmap: (json['heatmap'] as List? ?? const [])
            .map((d) => AttributedDay.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList(),
        platforms: (json['platforms'] as List? ?? const [])
            .map((p) => PlatformResult.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
      );
}
