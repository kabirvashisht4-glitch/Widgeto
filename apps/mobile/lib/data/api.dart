import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Talks to the Widgeto API and remembers the user's handles.
class WidgetoApi {
  /// Point this at your deployment. The GitHub token lives on the server, so
  /// the app ships no secrets at all.
  static const base = String.fromEnvironment(
    'WIDGETO_API',
    defaultValue: 'https://widgeto.vercel.app',
  );

  static const platforms = ['github', 'codeforces', 'leetcode', 'atcoder'];

  /// A real, recognisable handle per platform — a placeholder that shows the
  /// shape expected beats one that just repeats the field name.
  static String hintFor(String platform) => switch (platform) {
        'github' => 'torvalds',
        'codeforces' => 'tourist',
        'leetcode' => 'lee215',
        'atcoder' => 'tourist',
        _ => 'username',
      };

  static Future<Map<String, String>> loadHandles() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, String>{};
    for (final p in platforms) {
      final v = prefs.getString('handle_$p');
      if (v != null && v.isNotEmpty) out[p] = v;
    }
    return out;
  }

  static Future<void> saveHandles(Map<String, String> handles) async {
    final prefs = await SharedPreferences.getInstance();
    for (final p in platforms) {
      final v = handles[p]?.trim() ?? '';
      if (v.isEmpty) {
        await prefs.remove('handle_$p');
      } else {
        await prefs.setString('handle_$p', v);
      }
    }
  }

  /// The device's current UTC offset, as `UTC+05:30`.
  ///
  /// Flutter exposes `timeZoneName` as an abbreviation like `IST`, which is
  /// ambiguous between India and Israel; and abbreviations such as `EST` mean
  /// a *fixed* offset with no daylight saving, so they drift for half the year.
  /// The raw offset has neither problem — it is exactly right for today, which
  /// is all a streak needs.
  static String _deviceZone() {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final h = offset.inHours.abs().toString().padLeft(2, '0');
    final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }

  static Future<Activity> fetch(Map<String, String> handles, {String? timezone}) async {
    final query = <String, String>{
      // The server computes the streak in this zone. Getting it from the device
      // is the whole reason streaks line up with what the user expects.
      'tz': timezone ?? _deviceZone(),
    };
    handles.forEach((k, v) {
      if (v.trim().isNotEmpty) query[k] = v.trim();
    });

    final uri = Uri.parse('$base/api/streak').replace(queryParameters: query);
    final res = await http.get(uri).timeout(const Duration(seconds: 20));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'request failed (${res.statusCode})');
    }
    return Activity.fromJson(body);
  }
}
