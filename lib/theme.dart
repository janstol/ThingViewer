import 'package:flutter/material.dart';

// Blue drives the overall scheme (app bar, surfaces, secondary).
const _blue = Color(0xFF067BC2);
// Green overrides the primary cluster (buttons, FAB) to match the old app's
// Material 2 secondary/accent colour that users are familiar with.
const _green = Color(0xFF20BF55);

class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: _scheme(Brightness.light),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: _scheme(Brightness.dark),
      );

  /// Merges two M3 palettes: blue for surfaces/secondary, green for primary.
  static ColorScheme _scheme(Brightness brightness) {
    final blue = ColorScheme.fromSeed(seedColor: _blue, brightness: brightness);
    final green = ColorScheme.fromSeed(seedColor: _green, brightness: brightness);
    return blue.copyWith(
      primary: green.primary,
      onPrimary: green.onPrimary,
      primaryContainer: green.primaryContainer,
      onPrimaryContainer: green.onPrimaryContainer,
    );
  }
}
