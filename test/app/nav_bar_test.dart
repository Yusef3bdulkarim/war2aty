import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/theme/app_colors.dart';

import '../support/pump_app.dart';
import '../support/shell_harness.dart';

void main() {
  const ar = ArStrings();

  /// The icon sitting above [label] in the same destination.
  Color iconColorFor(WidgetTester tester, String label) {
    final icon = find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(StrokeIcon),
    );
    return tester.widget<StrokeIcon>(icon).color;
  }

  group('bottom nav', () {
    testWidgets('shows the four destinations with the design labels', (
      tester,
    ) async {
      await pumpApp(tester, shellHarness());

      expect(find.text(ar.navHome), findsOneWidget);
      expect(find.text(ar.navDocuments), findsOneWidget);
      expect(find.text(ar.navReminders), findsOneWidget);
      expect(find.text(ar.navSettings), findsOneWidget);
    });

    testWidgets('uses the design stroke icons, not Material ones', (
      tester,
    ) async {
      await pumpApp(tester, shellHarness());

      final glyphs = tester
          .widgetList<StrokeIcon>(find.byType(StrokeIcon))
          .map((i) => i.glyph)
          .toList();

      expect(glyphs, [
        StrokeGlyph.navHome,
        StrokeGlyph.navDocuments,
        StrokeGlyph.navReminders,
        StrokeGlyph.navSettings,
      ]);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('tints the selected destination and mutes the rest', (
      tester,
    ) async {
      await pumpApp(tester, shellHarness());

      expect(iconColorFor(tester, ar.navHome), AppColors.light.brandPrimary);
      expect(iconColorFor(tester, ar.navDocuments), AppColors.light.iconMuted);
    });

    testWidgets('moves the tint when another destination is selected', (
      tester,
    ) async {
      await pumpApp(tester, shellHarness(currentIndex: 2));

      expect(
        iconColorFor(tester, ar.navReminders),
        AppColors.light.brandPrimary,
      );
      expect(iconColorFor(tester, ar.navHome), AppColors.light.iconMuted);
    });

    testWidgets('tapping a destination switches branch', (tester) async {
      await pumpApp(tester, shellHarness());
      expect(find.text('/home'), findsOneWidget);

      await tester.tap(find.text(ar.navReminders));
      await tester.pumpAndSettle();

      expect(find.text('/reminders'), findsOneWidget);
      expect(
        iconColorFor(tester, ar.navReminders),
        AppColors.light.brandPrimary,
      );
    });

    testWidgets('does not rely on colour alone to mark the selection', (
      tester,
    ) async {
      await pumpApp(tester, shellHarness(currentIndex: 2));

      expect(
        tester.getSemantics(find.text(ar.navReminders)),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.text(ar.navHome)),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('fits four destinations at the largest text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // English has the longest labels ("My documents"), so it overflows first.
      await pumpApp(
        tester,
        shellHarness(),
        locale: AppLocalizations.english,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(const EnStrings().navDocuments), findsOneWidget);
    });

    testWidgets('gives every destination an equal share of the bar', (
      tester,
    ) async {
      await pumpApp(tester, shellHarness());

      final widths = [
        ar.navHome,
        ar.navDocuments,
        ar.navReminders,
        ar.navSettings,
      ].map((l) => tester.getSize(find.text(l)).width).toList();

      // Equal shares mean no destination can crowd out its neighbours.
      final slotWidth = tester
          .getSize(
            find
                .ancestor(
                  of: find.text(ar.navHome),
                  matching: find.byType(Padding),
                )
                .first,
          )
          .width;
      for (final width in widths) {
        expect(width, lessThanOrEqualTo(slotWidth));
      }
    });

    testWidgets('each destination is an activatable button', (tester) async {
      await pumpApp(tester, shellHarness());

      // Without `hasTapAction` a screen reader announces the tab but cannot
      // activate it — excluding the subtree drops the InkResponse's action.
      expect(
        tester.getSemantics(find.text(ar.navSettings)),
        isSemantics(isButton: true, hasTapAction: true, label: ar.navSettings),
      );
    });
  });
}
