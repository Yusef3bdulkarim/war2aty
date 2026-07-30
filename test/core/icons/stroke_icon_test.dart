import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';

void main() {
  group('glyph data', () {
    test('every glyph parses into a drawable outline', () {
      for (final glyph in StrokeGlyph.values) {
        final path = strokeGlyphPath(glyph);

        expect(
          path.computeMetrics(),
          isNotEmpty,
          reason: '$glyph produced an empty path',
        );
      }
    });

    test('every glyph stays inside the design\'s 24×24 viewBox', () {
      for (final glyph in StrokeGlyph.values) {
        final bounds = strokeGlyphPath(glyph).getBounds();

        expect(bounds.left, greaterThanOrEqualTo(0), reason: '$glyph');
        expect(bounds.top, greaterThanOrEqualTo(0), reason: '$glyph');
        expect(bounds.right, lessThanOrEqualTo(24), reason: '$glyph');
        expect(bounds.bottom, lessThanOrEqualTo(24), reason: '$glyph');
      }
    });

    test('the appointment card keeps the rect geometry it was drawn from', () {
      // The design draws this one as `<rect x=3 y=4 width=18 height=16 rx=3/>`,
      // which had to be rewritten as a path; this pins the conversion.
      final bounds = strokeGlyphPath(StrokeGlyph.appointment).getBounds();

      expect(bounds.left, closeTo(3, 0.01));
      expect(bounds.top, closeTo(4, 0.01));
      expect(bounds.width, closeTo(18, 0.01));
      expect(bounds.height, closeTo(16, 0.01));
    });

    test('the settings gear keeps the circle it was drawn from', () {
      // Likewise `<circle cx=12 cy=12 r=3/>`, rewritten as two arcs.
      final metrics = strokeGlyphPath(
        StrokeGlyph.navSettings,
      ).computeMetrics().toList();

      expect(metrics.length, 2, reason: 'gear outline plus centre circle');

      final circle = metrics
          .map((m) => m.length)
          .reduce((a, b) => a < b ? a : b);
      // Radius 3, shrunk by the viewBox fit — a closed ring, not a stray line.
      expect(circle, closeTo(2 * 3.14159 * 3 * (24 / 26), 1));
    });

    test(
      'a glyph drawn larger than the viewBox is scaled to fit, not clipped',
      () {
        // The design's gear spans ~26×24 inside a 24×24 viewBox.
        final bounds = strokeGlyphPath(StrokeGlyph.navSettings).getBounds();

        expect(bounds.width, lessThanOrEqualTo(24));
        expect(bounds.height, lessThanOrEqualTo(24));
        // Centred in the box rather than pinned to a corner.
        expect(bounds.center.dx, closeTo(12, 0.5));
        expect(bounds.center.dy, closeTo(12, 0.5));
      },
    );

    test('a glyph that already fits is left exactly as drawn', () {
      // Untouched: the tick still spans the coordinates the design gave it.
      final bounds = strokeGlyphPath(StrokeGlyph.check).getBounds();

      expect(bounds, const Rect.fromLTRB(4, 6, 20, 17));
    });

    test('document kinds are listed in the order onboarding shows them', () {
      expect(documentKindGlyphs, [
        StrokeGlyph.appointment,
        StrokeGlyph.invoice,
        StrokeGlyph.government,
        StrokeGlyph.education,
      ]);
    });
  });

  group('StrokeIcon', () {
    testWidgets('renders at the requested size', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: StrokeIcon(StrokeGlyph.check, color: Color(0xFF0E7C86)),
          ),
        ),
      );

      expect(tester.getSize(find.byType(StrokeIcon)), const Size(24, 24));
    });

    testWidgets('is hidden from assistive tech unless labelled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              StrokeIcon(StrokeGlyph.check, color: Color(0xFF0E7C86)),
              StrokeIcon(
                StrokeGlyph.shieldCheck,
                color: Color(0xFF0E7C86),
                semanticLabel: 'خصوصية',
              ),
            ],
          ),
        ),
      );

      expect(find.bySemanticsLabel('خصوصية'), findsOneWidget);
      expect(find.byType(ExcludeSemantics), findsOneWidget);
    });
  });
}
