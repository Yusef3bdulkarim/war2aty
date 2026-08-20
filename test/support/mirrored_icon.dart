import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';

/// The horizontal scale of the [Transform] wrapping the [StrokeIcon] that
/// draws [glyph]: `1` as authored for the app's Arabic/RTL default, `-1`
/// mirrored for a left-to-right layout (F12-T03).
///
/// Every directional glyph ([StrokeGlyph.arrowBack], [StrokeGlyph.
/// chevronForward]) is drawn once for the design's RTL default and flipped
/// by hand with `Transform.flip` wherever [Directionality] calls for it —
/// this reads that flip back out in a test instead of duplicating the
/// ancestor lookup at every call site.
double mirrorScaleX(WidgetTester tester, StrokeGlyph glyph) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(
          of: find.byWidgetPredicate(
            (w) => w is StrokeIcon && w.glyph == glyph,
          ),
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.getRow(0)[0];
}
