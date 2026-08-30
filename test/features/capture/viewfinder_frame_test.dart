import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/capture/domain/entities/document_quad.dart';
import 'package:war2aty/features/capture/domain/entities/unit_point.dart';
import 'package:war2aty/features/capture/presentation/widgets/viewfinder_frame.dart';

import '../../support/pump_app.dart';

/// The design's own camera comp (`Waraqti.dc.html` → `camera`): a 290×380
/// guide box on a 368 pt-wide screen — a 390×844 device mock with an 11 pt
/// bezel on each side.
const _designScreen = Size(368, 822);
const _designWidth = 290.0;
const _designHeight = 380.0;

/// Pumps a [ViewfinderFrame] filling a box of [available] and returns the
/// guide box's resolved size.
///
/// The frame's scan line animates forever, so this never settles.
Future<Size> _pumpFrame(WidgetTester tester, Size available) async {
  final frameKey = GlobalKey();
  await _pumpQuad(tester, available, null, frameKey);
  return tester.getSize(find.byKey(frameKey));
}

/// Pumps a frame following [quad] (or the static box when it is `null`) and
/// leaves it on screen for the caller to measure or re-pump.
Future<void> _pumpQuad(
  WidgetTester tester,
  Size available,
  DocumentQuad? quad,
  GlobalKey frameKey, {
  Locale locale = AppLocalizations.arabic,
  TextScaler? textScaler,
  AppColors? palette,
}) async {
  Widget frame = ViewfinderFrame(frameKey: frameKey, quad: quad);
  if (palette != null) {
    frame = AppColorsScope(colors: palette, child: frame);
  }

  await pumpApp(
    tester,
    Center(
      child: SizedBox(
        width: available.width,
        height: available.height,
        child: frame,
      ),
    ),
    settle: false,
    locale: locale,
    textScaler: textScaler,
  );
  await tester.pump();
}

/// The guide box's rect relative to the box the frame was given, so a quad's
/// bounding box can be compared with the fractions it came from.
Rect _guideRect(WidgetTester tester, GlobalKey frameKey) {
  final frame = tester.getRect(find.byKey(frameKey));
  final screen = tester.getRect(find.byType(ViewfinderFrame));
  return Rect.fromLTWH(
    frame.left - screen.left,
    frame.top - screen.top,
    frame.width,
    frame.height,
  );
}

/// A page filling the middle of the frame, tilted so a wrong rotation shows.
const _quad = DocumentQuad(
  topLeft: UnitPoint(0.15, 0.25),
  topRight: UnitPoint(0.8, 0.2),
  bottomRight: UnitPoint(0.85, 0.75),
  bottomLeft: UnitPoint(0.2, 0.8),
);

void main() {
  group('ViewfinderFrame', () {
    testWidgets('reproduces the design comp exactly at the design size', (
      tester,
    ) async {
      final size = await _pumpFrame(tester, _designScreen);

      expect(size.width, closeTo(_designWidth, 0.5));
      expect(size.height, closeTo(_designHeight, 0.5));
    });

    testWidgets('keeps the same share of the width on a narrower screen', (
      tester,
    ) async {
      // A small phone — the old fixed 290 pt box took 91% of this width and
      // left almost no margin.
      const available = Size(320, 700);
      final size = await _pumpFrame(tester, available);

      expect(
        size.width / available.width,
        closeTo(_designWidth / _designScreen.width, 0.001),
        reason: 'the framing should be the same share of the preview',
      );
      expect(size.width, lessThan(_designWidth));
    });

    testWidgets('keeps the same share of the width on a wider screen', (
      tester,
    ) async {
      const available = Size(430, 900);
      final size = await _pumpFrame(tester, available);

      expect(
        size.width / available.width,
        closeTo(_designWidth / _designScreen.width, 0.001),
      );
      expect(size.width, greaterThan(_designWidth));
    });

    testWidgets('holds the design proportions at every size', (tester) async {
      for (final available in const [
        _designScreen,
        Size(320, 700),
        Size(430, 900),
        Size(400, 300),
      ]) {
        final size = await _pumpFrame(tester, available);
        expect(
          size.width / size.height,
          closeTo(_designWidth / _designHeight, 0.001),
          reason: 'proportions must not drift at $available',
        );
      }
    });

    testWidgets('the height binds instead of the width on a short screen', (
      tester,
    ) async {
      // 400 × 0.788 = 315 wide would need 413 of height — only 300 is on
      // offer, so the box must shrink to fit rather than overflow.
      const available = Size(400, 300);
      final size = await _pumpFrame(tester, available);

      expect(size.height, closeTo(available.height, 0.5));
      expect(
        size.width,
        lessThan(available.width * ViewfinderFrame.widthFactor),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ViewfinderFrame following a detected document (F16-T06)', () {
    // Fits inside the 800x600 test surface, so the box is not clamped and
    // the fractions below map onto exactly these numbers.
    const available = Size(360, 560);

    testWidgets('without a quad it is exactly the F15-T12 static box', (
      tester,
    ) async {
      final frameKey = GlobalKey();
      await _pumpQuad(tester, available, null, frameKey);

      expect(
        tester.getSize(find.byKey(frameKey)),
        ViewfinderFrame.resolveSize(available),
      );
    });

    testWidgets('with a quad the guide box is the quad bounding rect', (
      tester,
    ) async {
      final frameKey = GlobalKey();
      await _pumpQuad(tester, available, _quad, frameKey);

      // This is the assertion F16-T08 depends on: the crop measures this very
      // box, so the quad's bounds and the measured guide box must be one rect.
      final rect = _guideRect(tester, frameKey);
      expect(rect.left, closeTo(0.15 * available.width, 0.5));
      expect(rect.top, closeTo(0.2 * available.height, 0.5));
      expect(rect.width, closeTo(0.7 * available.width, 0.5));
      expect(rect.height, closeTo(0.6 * available.height, 0.5));
    });

    testWidgets('a new detection is glided to, not snapped to', (tester) async {
      final frameKey = GlobalKey();
      await _pumpQuad(tester, available, _quad, frameKey);
      final before = _guideRect(tester, frameKey);

      const moved = DocumentQuad(
        topLeft: UnitPoint(0.05, 0.15),
        topRight: UnitPoint(0.7, 0.1),
        bottomRight: UnitPoint(0.75, 0.65),
        bottomLeft: UnitPoint(0.1, 0.7),
      );
      await _pumpQuad(tester, available, moved, frameKey);
      await tester.pump(const Duration(milliseconds: 60));
      final during = _guideRect(tester, frameKey);

      // Part of the way there: neither where it was nor where it is going.
      expect(during.left, lessThan(before.left));
      expect(during.left, greaterThan(0.05 * available.width));

      await tester.pump(const Duration(milliseconds: 200));
      final after = _guideRect(tester, frameKey);
      expect(after.left, closeTo(0.05 * available.width, 0.5));
    });

    testWidgets('losing the document returns the static box', (tester) async {
      final frameKey = GlobalKey();
      await _pumpQuad(tester, available, _quad, frameKey);
      await _pumpQuad(tester, available, null, frameKey);
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester.getSize(find.byKey(frameKey)),
        ViewfinderFrame.resolveSize(available),
      );
    });

    testWidgets('RTL does not mirror the quad — it is camera space', (
      tester,
    ) async {
      final ltrKey = GlobalKey();
      await _pumpQuad(
        tester,
        available,
        _quad,
        ltrKey,
        locale: AppLocalizations.english,
      );
      final ltr = _guideRect(tester, ltrKey);

      final rtlKey = GlobalKey();
      await _pumpQuad(tester, available, _quad, rtlKey);
      final rtl = _guideRect(tester, rtlKey);

      expect(rtl, ltr);
    });

    testWidgets('Large Text leaves the geometry alone', (tester) async {
      final frameKey = GlobalKey();
      await _pumpQuad(
        tester,
        available,
        _quad,
        frameKey,
        textScaler: const TextScaler.linear(2),
      );

      final rect = _guideRect(tester, frameKey);
      expect(rect.width, closeTo(0.7 * available.width, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('High Contrast renders without falling back', (tester) async {
      final frameKey = GlobalKey();
      await _pumpQuad(
        tester,
        available,
        _quad,
        frameKey,
        palette: AppColors.highContrast,
      );

      expect(find.byKey(frameKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a degenerate quad falls back to the static box', (
      tester,
    ) async {
      final frameKey = GlobalKey();
      const collapsed = DocumentQuad(
        topLeft: UnitPoint(0.5, 0.5),
        topRight: UnitPoint(0.5, 0.5),
        bottomRight: UnitPoint(0.5, 0.5),
        bottomLeft: UnitPoint(0.5, 0.5),
      );
      await _pumpQuad(tester, available, collapsed, frameKey);

      expect(
        tester.getSize(find.byKey(frameKey)),
        ViewfinderFrame.resolveSize(available),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
