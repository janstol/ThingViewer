import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/theme.dart';

/// Relative luminance per WCAG 2.x, used by [_contrastRatio].
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colours (>= 1.0, higher is better).
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a) + 0.05;
  final lb = _relativeLuminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  group('AppTheme light', () {
    final theme = AppTheme.light;
    final scheme = theme.colorScheme;

    test('brand colours land in the intended roles', () {
      expect(scheme.primary, brandGreen);
      expect(scheme.secondary, brandBlue);
      expect(theme.appBarTheme.backgroundColor, brandBlue);
      expect(theme.floatingActionButtonTheme.backgroundColor, brandGreen);
      expect(scheme.surface, Colors.white);
    });

    test('onPrimary on primary meets WCAG AA (>= 4.5:1)', () {
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dataAccent on surface meets WCAG AA (>= 4.5:1)', () {
      final dataAccent = theme.extension<BrandColors>()!.dataAccent;
      expect(
        _contrastRatio(dataAccent, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test(
      'onSecondaryContainer on secondaryContainer meets WCAG AA (>= 4.5:1)',
      () {
        expect(
          _contrastRatio(
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('onErrorContainer on errorContainer meets WCAG AA (>= 4.5:1)', () {
      expect(
        _contrastRatio(scheme.onErrorContainer, scheme.errorContainer),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('AppTheme dark', () {
    final theme = AppTheme.dark;
    final scheme = theme.colorScheme;

    test('brand colours land in the intended roles', () {
      expect(scheme.primary, brandGreen);
      expect(scheme.secondary, brandBlue);
      // Dark app bar matches the surface, not blue-on-black (fails AA).
      expect(theme.appBarTheme.backgroundColor, scheme.surface);
      expect(theme.floatingActionButtonTheme.backgroundColor, brandGreen);
      expect(scheme.surface, const Color(0xFF121212));
    });

    test('onPrimary on primary meets WCAG AA (>= 4.5:1)', () {
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dataAccent on surface meets WCAG AA (>= 4.5:1)', () {
      final dataAccent = theme.extension<BrandColors>()!.dataAccent;
      expect(
        _contrastRatio(dataAccent, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('app bar foreground on app bar background meets WCAG AA', () {
      final appBar = theme.appBarTheme;
      expect(
        _contrastRatio(appBar.foregroundColor!, appBar.backgroundColor!),
        greaterThanOrEqualTo(4.5),
      );
    });

    test(
      'onSecondaryContainer on secondaryContainer meets WCAG AA (>= 4.5:1)',
      () {
        expect(
          _contrastRatio(
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('onErrorContainer on errorContainer meets WCAG AA (>= 4.5:1)', () {
      expect(
        _contrastRatio(scheme.onErrorContainer, scheme.errorContainer),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
