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

    test('every SnackBar floats with rounded corners (F26-T03)', () {
      for (final (theme, colors) in [
        (AppTheme.light(), AppColors.light),
        (AppTheme.highContrast(), AppColors.highContrast),
      ]) {
        final snackBar = theme.snackBarTheme;
        expect(snackBar.behavior, SnackBarBehavior.floating);
        expect(snackBar.insetPadding, const EdgeInsets.fromLTRB(16, 0, 16, 16));
        expect(
          snackBar.shape,
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        );
        expect(snackBar.backgroundColor, colors.ink);
        expect(snackBar.contentTextStyle?.color, colors.onBrand);
        expect(snackBar.contentTextStyle?.fontFamily, 'Cairo');
      }
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

  testWidgets('a plain SnackBar floats clear of the edges and the nav bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const navBarHeight = 80.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          // As the shell draws it: content runs under a translucent bar.
          extendBody: true,
          bottomNavigationBar: const SizedBox(height: navBarHeight),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم'))),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    // The visible card: the SnackBar widget's own box includes the inset.
    final rect = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(390 - 16));
    expect(rect.bottom, lessThanOrEqualTo(844 - navBarHeight));
  });
}
