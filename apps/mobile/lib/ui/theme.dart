import 'package:flutter/material.dart';

/// One palette, three surfaces: the app, the in-app widget preview, and the
/// native home-screen faces all read from here so they cannot drift apart.

// ---- platform identity ----
const kGitHub = Color(0xFF39D353);
const kCodeforces = Color(0xFF4AA3E0);
const kLeetCode = Color(0xFFFFA116);
const kAtCoder = Color(0xFFB08D4F);
const kFlameHot = Color(0xFFFFB43D);
const kDanger = Color(0xFFFF5C5C);

Color platformColor(String platform) => switch (platform) {
      'github' => kGitHub,
      'codeforces' => kCodeforces,
      'leetcode' => kLeetCode,
      'atcoder' => kAtCoder,
      _ => const Color(0xFF5F6773),
    };

String platformLabel(String platform) => switch (platform) {
      'github' => 'GitHub',
      'codeforces' => 'Codeforces',
      'leetcode' => 'LeetCode',
      'atcoder' => 'AtCoder',
      _ => platform,
    };

/// Two-letter mark used on the connect tiles.
String platformMark(String platform) => switch (platform) {
      'github' => 'GH',
      'codeforces' => 'CF',
      'leetcode' => 'LC',
      'atcoder' => 'AC',
      _ => '??',
    };

/// The surface colours that differ between light and dark. Grouped in one
/// object so a widget face can be painted in either theme without the whole
/// app having to switch with it — the home-screen widget's theme is a separate
/// choice from the app's.
@immutable
class Skin {
  const Skin({
    required this.ground,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.text,
    required this.dim,
    required this.faint,
    required this.empty,
  });

  final Color ground;
  final Color surface;
  final Color surfaceAlt;
  final Color line;
  final Color text;
  final Color dim;
  final Color faint;

  /// An unworked day in the contribution grid.
  final Color empty;

  static const dark = Skin(
    ground: Color(0xFF08090B),
    surface: Color(0xFF14171D),
    surfaceAlt: Color(0xFF1B1F27),
    line: Color(0xFF262B35),
    text: Color(0xFFECEEF2),
    dim: Color(0xFF98A0AD),
    faint: Color(0xFF5F6773),
    empty: Color(0xFF1A1E26),
  );

  static const light = Skin(
    ground: Color(0xFFFBFBFC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF2F3F6),
    line: Color(0xFFE1E4EA),
    text: Color(0xFF14171D),
    dim: Color(0xFF5C6472),
    faint: Color(0xFF98A0AD),
    empty: Color(0xFFEBEDF0),
  );

  static Skin of(Brightness b) => b == Brightness.dark ? dark : light;
}

/// Which palette the home-screen widget uses. Separate from the app's own
/// theme: people theme a home screen to match a wallpaper, not to match the
/// app they configured it in.
enum WidgetSkin { dark, light, system }

ThemeData widgetoTheme(Brightness brightness) {
  final s = Skin.of(brightness);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: s.ground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGitHub,
      brightness: brightness,
      surface: s.ground,
      error: kDanger,
    ),
    dividerTheme: DividerThemeData(color: s.line, thickness: 1),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: s.text, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      titleMedium: TextStyle(color: s.text, fontSize: 16, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: s.text, fontSize: 14, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(color: s.faint, fontSize: 10.5, letterSpacing: 1.8, fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(color: s.dim, fontSize: 14),
      bodySmall: TextStyle(color: s.faint, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surfaceAlt,
      labelStyle: TextStyle(color: s.faint, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kGitHub, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGitHub,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
