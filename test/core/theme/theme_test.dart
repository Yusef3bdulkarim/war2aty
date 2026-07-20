import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/core/theme/app_radii.dart';
import 'package:war2aty/core/theme/app_spacing.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/theme/app_typography.dart';

void main() {
  group('tokens', () {
    test('brand teal matches the Waraqti design', () {
      expect(AppColors.light.brandPrimary, const Color(0xFF0E7C86));
      expect(AppColors.light.brandDeep, const Color(0xFF0A5C64));
      expect(AppColors.light.bgBase, const Color(0xFFE9E6DF));
    });

    test('high-contrast differs from light for text and borders', () {
      expect(AppColors.highContrast.ink, isNot(AppColors.light.ink));
      expect(AppColors.highContrast.border, isNot(AppColors.light.border));
    });

    test('spacing scale is ascending from the 4-based rhythm', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.screenHorizontal, 16);
      expect(AppSpacing.xxxl, 32);
    });

    test('radii scale covers buttons through pills', () {
      expect(AppRadii.md, 14);
      expect(AppRadii.lg, 18);
      expect(AppRadii.pill, 999);
    });
  });

  group('typography', () {
    test('uses the bundled Cairo family and design body size', () {
      expect(AppTypography.fontFamily, 'Cairo');
      expect(AppTypography.bodyMedium.fontSize, 15);
      expect(AppTypography.bodyMedium.height, 1.7);
      expect(AppTypography.headlineLarge.fontWeight, FontWeight.w800);
    });
  });

  group('theme assembly', () {
    test('light theme wires tokens + Cairo', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.light.bgBase);
      expect(theme.colorScheme.primary, AppColors.light.brandPrimary);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
      expect(theme.textTheme.bodyMedium?.color, AppColors.light.ink);
    });

    test('high-contrast theme uses the HC palette', () {
      final theme = AppTheme.highContrast();
      expect(theme.colorScheme.primary, AppColors.highContrast.brandPrimary);
      expect(theme.textTheme.bodyMedium?.color, AppColors.highContrast.ink);
    });

    testWidgets('renders offline under the theme without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Center(child: Text('ورقتي'))),
        ),
      );
      expect(find.text('ورقتي'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('ورقتي'));
      expect(textWidget.data, 'ورقتي');
    });
  });
}
