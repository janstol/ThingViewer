import 'package:flutter/material.dart';

// Brand colours from the old Material 2 app (AppThemeColors).
const brandBlue = Color(0xFF067BC2);
const brandGreen = Color(0xFF20BF55);

// Text/chart colour that reads on both a white and a near-black surface —
// brandGreen itself is only 2.43:1 on white, too low for text (see
// BrandColors.dataAccent).
const _dataAccentLight = Color(0xFF0F7A34);
const _dataAccentDark = Color(0xFF3DD672);

// Same rationale as dataAccent above, tuned for a distinct "this was
// changed" role (e.g. the import preview's UPDATE label) — verified >= 4.5:1
// on both surfaces in test/theme_test.dart.
const _changeAccentLight = Color(0xFFB24C00);
const _changeAccentDark = Color(0xFFFF6D00);

// Same contrast-verified hex pair as changeAccent above, kept as its own
// named role (chart min/max markers) so the two can diverge later.
const _markerAccentLight = Color(0xFFB24C00);
const _markerAccentDark = Color(0xFFFF6D00);

/// Extra brand colour roles that don't map onto a Material [ColorScheme]
/// role (e.g. a chart series colour distinct from the primary fill colour).
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  final Color dataAccent;
  final Color changeAccent;
  final Color markerAccent;

  const BrandColors({
    required this.dataAccent,
    required this.changeAccent,
    required this.markerAccent,
  });

  static const light = BrandColors(
    dataAccent: _dataAccentLight,
    changeAccent: _changeAccentLight,
    markerAccent: _markerAccentLight,
  );
  static const dark = BrandColors(
    dataAccent: _dataAccentDark,
    changeAccent: _changeAccentDark,
    markerAccent: _markerAccentDark,
  );

  @override
  BrandColors copyWith({
    Color? dataAccent,
    Color? changeAccent,
    Color? markerAccent,
  }) => BrandColors(
    dataAccent: dataAccent ?? this.dataAccent,
    changeAccent: changeAccent ?? this.changeAccent,
    markerAccent: markerAccent ?? this.markerAccent,
  );

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      dataAccent: Color.lerp(dataAccent, other.dataAccent, t)!,
      changeAccent: Color.lerp(changeAccent, other.changeAccent, t)!,
      markerAccent: Color.lerp(markerAccent, other.markerAccent, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static final ThemeData light = _theme(Brightness.light);
  static final ThemeData dark = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [isDark ? BrandColors.dark : BrandColors.light],
      appBarTheme: AppBarThemeData(
        backgroundColor: isDark ? scheme.surface : brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandGreen,
        foregroundColor: Colors.black,
      ),
      // colorScheme.primary (brandGreen) is only 2.43:1 on white, too low
      // for text (see BrandColors.dataAccent above) — TextButton defaults
      // to colorScheme.primary, so route it through dataAccent instead.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? _dataAccentDark : _dataAccentLight,
        ),
      ),
    );
  }

  /// Declares brand colour roles explicitly rather than letting
  /// [ColorScheme.fromSeed]'s tonal-palette generator (which crushes
  /// chroma and tints surfaces) decide them. `fromSeed` still fills in
  /// [ColorScheme.error]/[ColorScheme.outline]/inverse-* sensibly.
  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surface = isDark ? const Color(0xFF121212) : Colors.white;
    final surfaceContainerLow = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF7F7F7);
    final surfaceContainer = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF2F2F2);
    final surfaceContainerHigh = isDark
        ? const Color(0xFF242424)
        : const Color(0xFFEBEBEB);

    // Container tones for the green cluster must come from a green-seeded
    // palette, not the blue base seed below — otherwise primaryContainer
    // stays blue-derived while primary is green (the "half-done splice"
    // that produced mismatched buttons before this rewrite).
    final greenContainers = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: brightness,
    );

    return ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: brightness,
      // Green = action (buttons, FAB); black/white foreground per WCAG,
      // see AppTheme.floatingActionButtonTheme.
      primary: brandGreen,
      onPrimary: Colors.black,
      primaryContainer: greenContainers.primaryContainer,
      onPrimaryContainer: greenContainers.onPrimaryContainer,
      // Blue = identity/selection (app bar, selected list tiles).
      secondary: brandBlue,
      onSecondary: Colors.white,
      surface: surface,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      // Transparent tint stops M3 from washing elevated surfaces with a
      // coloured overlay — the main cause of the "muddy" default look.
      surfaceTint: Colors.transparent,
    );
  }
}
