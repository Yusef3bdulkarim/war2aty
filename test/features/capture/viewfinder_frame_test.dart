import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  await pumpApp(
    tester,
    Center(
      child: SizedBox(
        width: available.width,
        height: available.height,
        child: ViewfinderFrame(frameKey: frameKey),
      ),
    ),
    settle: false,
  );
  await tester.pump();
  return tester.getSize(find.byKey(frameKey));
}

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
}
