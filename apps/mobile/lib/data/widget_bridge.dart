import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'models.dart';

/// Pushes data across to the native home-screen widgets.
///
/// The widget extension has a tiny memory budget and almost no time to run, so
/// it must never fetch or compute. Everything it needs is pre-rendered here
/// into the shared container; the native side only reads and draws.
class WidgetBridge {
  /// Must match the App Group on iOS and the provider package on Android.
  static const iosAppGroup = 'group.me.widgeto.shared';
  static const iosWidgetName = 'WidgetoWidget';
  static const androidProvider = 'StreakWidgetReceiver';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(iosAppGroup);
  }

  /// Encode the last [weeks] of the grid into a compact string the native
  /// widgets can parse without a JSON library: one `LP` pair per day, where L
  /// is intensity 0-4 and P is the dominant platform (g/c/l, or `-` if idle).
  static String _encodeGrid(List<AttributedDay> heatmap, int weeks) {
    final cells = heatmap.length > weeks * 7
        ? heatmap.sublist(heatmap.length - weeks * 7)
        : heatmap;

    var peak = 1;
    for (final d in cells) {
      if (d.count > peak) peak = d.count;
    }

    final buffer = StringBuffer();
    for (final d in cells) {
      if (d.count <= 0) {
        buffer.write('0-');
        continue;
      }
      final ratio = d.count / peak;
      final level = ratio > 0.66 ? 4 : (ratio > 0.33 ? 3 : (ratio > 0.12 ? 2 : 1));
      final platform = switch (d.dominantPlatform) {
        'github' => 'g',
        'codeforces' => 'c',
        'leetcode' => 'l',
        _ => '-',
      };
      buffer.write('$level$platform');
    }
    return buffer.toString();
  }

  static Future<void> push(Activity activity) async {
    final s = activity.summary;

    await Future.wait([
      HomeWidget.saveWidgetData<int>('streak', s.currentStreak),
      HomeWidget.saveWidgetData<int>('longest', s.longestStreak),
      HomeWidget.saveWidgetData<String>('status', s.status),
      HomeWidget.saveWidgetData<int>('total', s.totalContributions),
      HomeWidget.saveWidgetData<String>('grid', _encodeGrid(activity.heatmap, 20)),
      HomeWidget.saveWidgetData<String>('updatedAt', DateTime.now().toIso8601String()),
      HomeWidget.saveWidgetData<String>(
        'handles',
        jsonEncode({for (final p in activity.platforms) p.platform: p.handle}),
      ),
    ]);

    await HomeWidget.updateWidget(
      iOSName: iosWidgetName,
      androidName: androidProvider,
    );
  }
}
