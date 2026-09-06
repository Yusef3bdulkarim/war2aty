import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/theme/app_colors.dart';

/// WCAG 2.x contrast ratio between two colors, via the standard relative
/// luminance formula (https://www.w3.org/TR/WCAG21/#contrast-minimum).
///
/// This is the regression gate for [AppColors] — the only place in the repo
/// that actually measures the numbers the palette's own "targeting WCAG-AA"
/// doc comment promises (see `app_colors.dart`). Thresholds below follow
/// WCAG AA: 4.5:1 for normal text, 3:1 for large text (≥18pt, or ≥14pt bold)
/// and UI components.
double _contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    double linearize(double channel) => channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * linearize(c.r) +
        0.7152 * linearize(c.g) +
        0.0722 * linearize(c.b);
  }

  final la = luminance(a);
  final lb = luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppColors.light — WCAG AA contrast (F12-T01)', () {
    const c = AppColors.light;

    test('ink on bgBase / surface meets 4.5:1 (normal text)', () {
      expect(_contrastRatio(c.ink, c.bgBase), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(c.ink, c.surface), greaterThanOrEqualTo(4.5));
    });

    test('textBody / textSecondary on surface meet 4.5:1', () {
      expect(_contrastRatio(c.textBody, c.surface), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(c.textSecondary, c.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onBrand on brandPrimary (button labels) meets 4.5:1', () {
      expect(
        _contrastRatio(c.onBrand, c.brandPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('status ink on its tint meets 4.5:1 (success / warning / error)', () {
      expect(
        _contrastRatio(c.successInk, c.successTint),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(c.warningInk, c.warningTint),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrastRatio(c.error, c.errorTint), greaterThanOrEqualTo(4.5));
    });

    // Known gaps below AA — see docs/features/F12-T01-accessibility-audit.md.
    // CLAUDE.md forbids editing the approved design tokens unilaterally, so
    // these are pinned rather than "fixed": a floor that lets the ratio stay
    // where it is but fails loudly if a future change makes it worse.
    test(
      'KNOWN GAP: textMuted on surface sits below the 3:1 floor (~2.76:1)',
      () {
        final ratio = _contrastRatio(c.textMuted, c.surface);
        expect(ratio, greaterThanOrEqualTo(2.7));
        expect(
          ratio,
          lessThan(3.0),
          reason:
              'textMuted now clears the WCAG large-text/UI floor — update '
              'the audit doc and this pin, this is progress not a regression.',
        );
      },
    );

    test(
      'KNOWN GAP: textCaption on surface is below the 4.5:1 text floor (~4.19:1)',
      () {
        final ratio = _contrastRatio(c.textCaption, c.surface);
        expect(ratio, greaterThanOrEqualTo(4.1));
        expect(
          ratio,
          lessThan(4.5),
          reason:
              'textCaption now clears WCAG AA normal-text contrast — update '
              'the audit doc and this pin, this is progress not a regression.',
        );
      },
    );
  });

  group('AppColors.highContrast — WCAG AA contrast (F12-T01)', () {
    const c = AppColors.highContrast;

    test('ink on bgBase / surface meets 4.5:1', () {
      expect(_contrastRatio(c.ink, c.bgBase), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(c.ink, c.surface), greaterThanOrEqualTo(4.5));
    });

    test(
      'textBody / textSecondary / textMuted / textCaption on surface all meet 4.5:1',
      () {
        expect(
          _contrastRatio(c.textBody, c.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(c.textSecondary, c.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(c.textMuted, c.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(c.textCaption, c.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('onBrand on brandPrimary meets 4.5:1', () {
      expect(
        _contrastRatio(c.onBrand, c.brandPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('status ink on its tint meets 4.5:1 (success / warning / error)', () {
      expect(
        _contrastRatio(c.successInk, c.successTint),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(c.warningInk, c.warningTint),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrastRatio(c.error, c.errorTint), greaterThanOrEqualTo(4.5));
    });
  });
}
