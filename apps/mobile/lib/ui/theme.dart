import 'package:flutter/material.dart';

/// The same tokens as the website, so the app, the site and the home-screen
/// widget are visibly one product.
const kBg = Color(0xFF08090B);
const kSurface = Color(0xFF14171D);
const kSurface2 = Color(0xFF1B1F27);
const kLine = Color(0xFF262B35);
const kText = Color(0xFFECEEF2);
const kTextDim = Color(0xFF98A0AD);
const kTextFaint = Color(0xFF5F6773);

const kGitHub = Color(0xFF39D353);
const kCodeforces = Color(0xFF4AA3E0);
const kLeetCode = Color(0xFFFFA116);
const kFlameHot = Color(0xFFFFB43D);
const kDanger = Color(0xFFFF5C5C);

Color platformColor(String platform) => switch (platform) {
      'github' => kGitHub,
      'codeforces' => kCodeforces,
      'leetcode' => kLeetCode,
      _ => kTextFaint,
    };

final widgetoTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    surface: kBg,
    primary: kGitHub,
    onPrimary: Colors.black,
    error: kDanger,
  ),
  dividerTheme: const DividerThemeData(color: kLine, thickness: 1),
  textTheme: const TextTheme(
    titleMedium: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w600),
    labelLarge: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(color: kTextFaint, fontSize: 10.5, letterSpacing: 1.8),
    bodyMedium: TextStyle(color: kTextDim, fontSize: 14),
    bodySmall: TextStyle(color: kTextFaint, fontSize: 12),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kSurface2,
    labelStyle: const TextStyle(color: kTextFaint, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kGitHub),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kGitHub,
      foregroundColor: Colors.black,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
);
