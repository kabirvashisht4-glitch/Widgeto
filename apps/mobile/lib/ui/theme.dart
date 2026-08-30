import 'package:flutter/material.dart';

/// One palette, three surfaces: the app, the in-app widget preview, and the
/// native home-screen faces all read from here so they cannot drift apart.

// ---- platform identity ----
//
// These four are the only decorative-looking colours in the product that are
// not decorative: the grid is readable only because green always means GitHub.
const kGitHub = Color(0xFF3FB950);
const kCodeforces = Color(0xFF58A6FF);
const kLeetCode = Color(0xFFFFA657);
const kAtCoder = Color(0xFFD0B070);

// ---- signals ----
const kOk = Color(0xFF3FB950);
const kDanger = Color(0xFFFF7B72);

/// Kept as the default widget accent. Choosing a colour for something that
/// sits on your own home screen is a real preference, so the widget keeps an
/// accent palette even though the app chrome does not.
const kFlameHot = Color(0xFFFFB43D);

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
    ground: Color(0xFF09090B),
    surface: Color(0xFF0E0E10),
    surfaceAlt: Color(0xFF18181B),
    line: Color(0xFF3F3F46),
    text: Color(0xFFFAFAFA),
    dim: Color(0xFFA1A1AA),
    // 5.4:1 on the dark ground. Captions live at 8-11pt, which is exactly
    // where a too-light grey stops being readable.
    faint: Color(0xFF8B8B95),
    empty: Color(0xFF1C1C1F),
  );

  static const light = Skin(
    ground: Color(0xFFF7F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEEEF0),
    // Near-black borders: structure is drawn, not implied by a soft grey.
    line: Color(0xFF18181B),
    text: Color(0xFF09090B),
    dim: Color(0xFF52525B),
    faint: Color(0xFF5F5F68),
    empty: Color(0xFFE4E4E7),
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
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(s.line),
      radius: Radius.zero,
    ),
    dividerTheme: DividerThemeData(color: s.line, thickness: 1.5),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
          color: s.text, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.02),
      titleMedium: TextStyle(color: s.text, fontSize: 16, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: s.text, fontSize: 14, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(color: s.faint, fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: s.dim, fontSize: 14),
      bodySmall: TextStyle(color: s.faint, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surface,
      labelStyle: TextStyle(color: s.faint, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: s.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: s.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: s.text, width: 2),
      ),
    ),
    // The primary action is the page's ink, not a colour — the same rule the
    // website follows, so a green button cannot be mistaken for a GitHub one.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: s.text,
        foregroundColor: s.ground,
        minimumSize: const Size.fromHeight(54),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    ),
  );
}
