import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// True once the native side has accepted us. When it hasn't — an older OS,
  /// a plugin that isn't registered, or a platform with no home screen at all
  /// — the app still runs; it just can't push to a widget.
  static bool available = false;

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(iosAppGroup);
      available = true;
    } catch (err) {
      // Never fatal. The widget is the point of the app, but being unable to
      // reach it is no reason to refuse to launch — the user would get a blank
      // screen instead of an explanation.
      available = false;
      debugPrint('Widgeto: home-screen widget unavailable ($err)');
    }
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

  /// Ask the launcher to place the widget for us.
  ///
  /// Android supports this from API 26 on most launchers; iOS has no
  /// equivalent and never will, since only the user may place a widget.
  /// Returns false when the platform declines, so the caller can explain the
  /// manual route instead of appearing to do nothing.
  static Future<bool> requestPin() async {
    if (!available) return false;
    try {
      await HomeWidget.requestPinWidget(
        name: androidProvider,
        androidName: androidProvider,
        qualifiedAndroidName: 'me.widgeto.widget.$androidProvider',
      );
      return true;
    } catch (err) {
      debugPrint('Widgeto: launcher declined to pin the widget ($err)');
      return false;
    }
  }

  static Future<void> push(Activity activity) async {
    if (!available) return;
    final s = activity.summary;

    try {
      await _write(activity, s);
    } catch (err) {
      // A failed push leaves the widget showing older data, which is strictly
      // better than failing the refresh the user just asked for.
      debugPrint('Widgeto: could not update the home-screen widget ($err)');
    }
  }

  static Future<void> _write(Activity activity, StreakSummary s) async {
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
