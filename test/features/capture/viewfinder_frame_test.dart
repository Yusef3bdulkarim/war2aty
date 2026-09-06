import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/capture/domain/entities/document_quad.dart';
import 'package:war2aty/features/capture/domain/entities/unit_point.dart';
import 'package:war2aty/features/capture/presentation/widgets/viewfinder_frame.dart';

import '../../support/pump_app.dart';

/// Fits inside the 800x600 test surface, so the box is not clamped and the
/// fractions below map onto exactly these numbers.
const _available = Size(360, 560);

/// A page filling the middle of the frame, tilted so a wrong rotation shows.
const _quad = DocumentQuad(
  topLeft: UnitPoint(0.15, 0.25),
  topRight: UnitPoint(0.8, 0.2),
  bottomRight: UnitPoint(0.85, 0.75),
  bottomLeft: UnitPoint(0.2, 0.8),
);

/// Pumps a [ViewfinderFrame] filling a box of [_available].
///
/// The scan line animates forever, so this never settles.
Future<void> _pumpQuad(
  WidgetTester tester,
  DocumentQuad? quad, {
  Locale locale = AppLocalizations.arabic,
  TextScaler? textScaler,
  AppColors? palette,
}) async {
  Widget frame = ViewfinderFrame(quad: quad);
  if (palette != null) {
    frame = AppColorsScope(colors: palette, child: frame);
  }

  await pumpApp(
    tester,
    Center(
      child: SizedBox(
        width: _available.width,
        height: _available.height,
        child: frame,
      ),
    ),
    settle: false,
    locale: locale,
    textScaler: textScaler,
  );
  await tester.pump();
}

/// The quad currently being painted, read off the overlay's painter.
DocumentQuad? _drawnQuad(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byKey(ViewfinderFrame.quadOverlayKey),
    matching: find.byType(CustomPaint),
  );
  if (finder.evaluate().isEmpty) return null;
  return (tester.widget<CustomPaint>(finder.first).painter! as QuadPainter)
      .quad;
}

void main() {
  group('ViewfinderFrame', () {
    testWidgets('draws nothing at all when no document is detected', (
      tester,
    ) async {
      await _pumpQuad(tester, null);

      // The static guide box is gone for good: with no detection there is no
      // frame on screen, not a fallback rectangle.
      expect(find.byKey(ViewfinderFrame.quadOverlayKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws the detected document', (tester) async {
      await _pumpQuad(tester, _quad);

      expect(find.byKey(ViewfinderFrame.quadOverlayKey), findsOneWidget);
      expect(_drawnQuad(tester), _quad);
    });

    testWidgets('a new detection is glided to, not snapped to', (tester) async {
      await _pumpQuad(tester, _quad);

      const moved = DocumentQuad(
        topLeft: UnitPoint(0.05, 0.15),
        topRight: UnitPoint(0.7, 0.1),
        bottomRight: UnitPoint(0.75, 0.65),
        bottomLeft: UnitPoint(0.1, 0.7),
      );
      await _pumpQuad(tester, moved);
      await tester.pump(const Duration(milliseconds: 60));

      // Part of the way there: neither where it was nor where it is going.
      final during = _drawnQuad(tester)!;
      expect(during, isNot(_quad));
      expect(during, isNot(moved));
      expect(during.topLeft.x, lessThan(_quad.topLeft.x));
      expect(during.topLeft.x, greaterThan(moved.topLeft.x));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_drawnQuad(tester), moved);
    });

    testWidgets('losing the document clears the guide', (tester) async {
      await _pumpQuad(tester, _quad);
      await _pumpQuad(tester, null);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(ViewfinderFrame.quadOverlayKey), findsNothing);
    });

    testWidgets('RTL does not mirror the quad — it is camera space', (
      tester,
    ) async {
      await _pumpQuad(tester, _quad, locale: AppLocalizations.english);
      final ltr = _drawnQuad(tester);

      await _pumpQuad(tester, _quad);

      expect(_drawnQuad(tester), ltr);
    });

    testWidgets('Large Text leaves the geometry alone', (tester) async {
      await _pumpQuad(tester, _quad, textScaler: const TextScaler.linear(2));

      expect(_drawnQuad(tester), _quad);
      expect(tester.takeException(), isNull);
    });

    testWidgets('High Contrast renders without falling back', (tester) async {
      await _pumpQuad(tester, _quad, palette: AppColors.highContrast);

      expect(find.byKey(ViewfinderFrame.quadOverlayKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a degenerate quad paints nothing', (tester) async {
      const collapsed = DocumentQuad(
        topLeft: UnitPoint(0.5, 0.5),
        topRight: UnitPoint(0.5, 0.5),
        bottomRight: UnitPoint(0.5, 0.5),
        bottomLeft: UnitPoint(0.5, 0.5),
      );
      await _pumpQuad(tester, collapsed);

      expect(find.byKey(ViewfinderFrame.quadOverlayKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
