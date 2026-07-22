import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/home/presentation/widgets/scan_actions.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  /// Builds the group, recording which action fired.
  ({Widget widget, List<String> taps}) buildActions() {
    final taps = <String>[];
    return (
      widget: ScanActions(
        onScan: () => taps.add('scan'),
        onPickImage: () => taps.add('pick'),
      ),
      taps: taps,
    );
  }

  group('ScanActions', () {
    testWidgets('offers both routes into a scan, and the privacy promise', (
      tester,
    ) async {
      await pumpApp(tester, buildActions().widget);

      expect(find.text(ar.homeScanTitle), findsOneWidget);
      expect(find.text(ar.homeScanSubtitle), findsOneWidget);
      expect(find.text(ar.homePickImage), findsOneWidget);
      expect(find.text(ar.homeImagePrivacyNote), findsOneWidget);
    });

    testWidgets('tapping the camera card starts a capture', (tester) async {
      final actions = buildActions();
      await pumpApp(tester, actions.widget);

      await tester.tap(find.text(ar.homeScanTitle));
      await tester.pumpAndSettle();

      expect(actions.taps, ['scan']);
    });

    testWidgets('tapping the gallery row picks an image', (tester) async {
      final actions = buildActions();
      await pumpApp(tester, actions.widget);

      await tester.tap(find.text(ar.homePickImage));
      await tester.pumpAndSettle();

      expect(actions.taps, ['pick']);
    });

    testWidgets('the privacy note is not tappable', (tester) async {
      final actions = buildActions();
      await pumpApp(tester, actions.widget);

      await tester.tap(find.text(ar.homeImagePrivacyNote));
      await tester.pumpAndSettle();

      // It explains, it does not act — tapping it must not start anything.
      expect(actions.taps, isEmpty);
    });

    testWidgets('uses the design camera, gallery and shield glyphs', (
      tester,
    ) async {
      await pumpApp(tester, buildActions().widget);

      final glyphs = tester
          .widgetList<StrokeIcon>(find.byType(StrokeIcon))
          .map((i) => i.glyph)
          .toSet();

      expect(glyphs, {
        StrokeGlyph.camera,
        StrokeGlyph.chevronForward,
        StrokeGlyph.gallery,
        StrokeGlyph.shield,
      });
    });

    testWidgets('the chevron points along the reading direction', (
      tester,
    ) async {
      double chevronScaleX(WidgetTester tester) {
        final transform = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byWidgetPredicate(
                  (w) =>
                      w is StrokeIcon && w.glyph == StrokeGlyph.chevronForward,
                ),
                matching: find.byType(Transform),
              )
              .first,
        );
        return transform.transform.getRow(0)[0];
      }

      await pumpApp(tester, buildActions().widget);
      expect(chevronScaleX(tester), 1, reason: 'RTL: points left as drawn');

      await pumpApp(
        tester,
        buildActions().widget,
        locale: AppLocalizations.english,
      );
      expect(chevronScaleX(tester), -1, reason: 'LTR: mirrored to point right');
    });

    testWidgets('announces the camera card as one activatable button', (
      tester,
    ) async {
      await pumpApp(tester, buildActions().widget);

      // `hasTapAction` is the part that matters: announcing it as a button is
      // not enough, because assistive tech activates a node through its tap
      // action — which excluding the subtree would otherwise drop.
      expect(
        tester.getSemantics(find.text(ar.homeScanTitle)),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label: ar.homeScanTitle,
          hint: ar.homeScanSubtitle,
        ),
      );
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        buildActions().widget,
        locale: AppLocalizations.english,
      );

      expect(find.text(en.homeScanTitle), findsOneWidget);
      expect(find.text(en.homePickImage), findsOneWidget);
      expect(find.text(en.homeImagePrivacyNote), findsOneWidget);
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        buildActions().widget,
        locale: AppLocalizations.english,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(en.homeScanTitle), findsOneWidget);
    });
  });
}
