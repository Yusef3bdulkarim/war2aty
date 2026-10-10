import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminders_empty_art.dart';

import '../../support/pump_app.dart';

void main() {
  group('RemindersEmptyArt', () {
    testWidgets('draws no shadow anywhere', (tester) async {
      // F29's whole second half is the owner removing the shadows from the
      // other two empty-state illustrations. A new one arriving with a
      // shadow would undo that, so every decoration in the subtree is
      // checked — not just the two shapes a shadow would be tempting on.
      await pumpApp(tester, const RemindersEmptyArt());

      final shadowed = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(RemindersEmptyArt),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow?.isNotEmpty ?? false)
          .toList();

      expect(shadowed, isEmpty);
    });

    testWidgets('separates its shapes with borders instead', (tester) async {
      // What replaces the shadows: the paper's hairline, the date chip's,
      // and the ring around the bell. If these ever go, the drawing
      // disappears into the page rather than looking flat on it.
      await pumpApp(tester, const RemindersEmptyArt());

      final bordered = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(RemindersEmptyArt),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null)
          .toList();

      expect(bordered, hasLength(3));
    });

    testWidgets('contributes nothing to the semantics tree', (tester) async {
      // Decoration. The title underneath carries the meaning, and a screen
      // reader announcing "bell, calendar" before it would only get in the
      // way.
      // Disposed inside the body, not in a tear-down: the framework verifies
      // every handle is released *before* tear-downs run.
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const RemindersEmptyArt());

      for (final icon in tester.widgetList<StrokeIcon>(
        find.byType(StrokeIcon),
      )) {
        expect(icon.semanticLabel, isNull);
      }
      // The tree itself, not the widget that is supposed to produce it: the
      // art is the only thing on screen, so an empty root node means it
      // contributed nothing at all.
      final root = tester.getSemantics(find.byType(RemindersEmptyArt));
      expect(root.label, isEmpty);
      expect(root.childrenCount, 0);

      handle.dispose();
    });

    testWidgets('carries no text, so nothing in it needs translating', (
      tester,
    ) async {
      // The date is a calendar glyph, not digits: the art is excluded from
      // semantics, so any text in it would be read by nobody and localized
      // by nothing — and Arabic-Indic digits would be wrong in English
      // anyway.
      await pumpApp(tester, const RemindersEmptyArt());

      expect(
        find.descendant(
          of: find.byType(RemindersEmptyArt),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('draws the bell and the date mark', (tester) async {
      await pumpApp(tester, const RemindersEmptyArt());

      final glyphs = tester
          .widgetList<StrokeIcon>(find.byType(StrokeIcon))
          .map((icon) => icon.glyph)
          .toList();

      expect(
        glyphs,
        containsAll(const [StrokeGlyph.navReminders, StrokeGlyph.calendar]),
      );
    });

    testWidgets('paints entirely inside its own bounds', (tester) async {
      // A `Stack` clips to its box, so a shape placed at a negative offset —
      // which is how the prototype drew the ring, and the obvious way to
      // write it — loses two of its sides silently. The box is sized to hold
      // the ring and the bell is inset instead; this catches a return to the
      // other arrangement. (It does not police the composition itself: a
      // shape moved *within* the bounds is still within them.)
      await pumpApp(tester, const RemindersEmptyArt());

      final box = tester.getRect(find.byType(RemindersEmptyArt));
      for (final decorated
          in find
              .descendant(
                of: find.byType(RemindersEmptyArt),
                matching: find.byType(DecoratedBox),
              )
              .evaluate()) {
        final child = tester.getRect(find.byWidget(decorated.widget));
        expect(box.contains(child.topLeft), isTrue, reason: '$child');
        expect(
          box.inflate(0.01).contains(child.bottomRight),
          isTrue,
          reason: '$child escapes $box',
        );
      }
    });

    testWidgets('keeps the bell on the same corner in both languages', (
      tester,
    ) async {
      // It is a picture, not a line of content — the bell belongs on the
      // same corner however the text around it runs.
      //
      // Scoped to the bell deliberately: the mock text lines inside the
      // paper *do* mirror, because a short line of text starts where text
      // starts. That is what the next test pins, and the two together are
      // the whole of the drawing's direction behaviour.
      await pumpApp(tester, const RemindersEmptyArt());
      final rtlBell = tester.getRect(_bell());

      await pumpApp(
        tester,
        const RemindersEmptyArt(),
        locale: AppLocalizations.english,
      );

      expect(tester.getRect(_bell()), rtlBell);
    });

    testWidgets('the mock text lines start where text starts', (tester) async {
      // The one directional thing in the drawing, and the prototype's own
      // behaviour: its bars are block elements narrower than their box, which
      // CSS aligns to the inline start. A part-width line pinned to the left
      // in Arabic would read as a paper written in the wrong language.
      //
      // Compared across the two languages rather than against the bar beside
      // it: the paper is tilted -7°, so `getRect` hands back a rotated bar's
      // bounding box, and two bars sharing an inline edge do not share a
      // bounding-box edge. The same bar measured in both directions is not
      // affected by the tilt.
      Rect lineAt(int index) => tester.getRect(_textLines().at(index));

      await pumpApp(tester, const RemindersEmptyArt());
      final rtlShort = lineAt(0);
      final rtlFull = lineAt(1);

      await pumpApp(
        tester,
        const RemindersEmptyArt(),
        locale: AppLocalizations.english,
      );

      // The 62% bar swings across the paper: right-hugging in Arabic,
      // left-hugging in English.
      expect(lineAt(0).center.dx, lessThan(rtlShort.center.dx));
      // And the full-width bar does not move at all — it fills the content
      // box, so it has no start edge to pick. That is what makes the line
      // above a statement about alignment rather than about layout drift.
      expect(
        lineAt(1).center.dx,
        moreOrLessEquals(rtlFull.center.dx, epsilon: 0.01),
      );
    });

    testWidgets('survives large text without changing size', (tester) async {
      // It has no text, so nothing in it should scale — the layout around it
      // relies on the drawing staying the size it reserves.
      await pumpApp(tester, const RemindersEmptyArt());
      final normal = tester.getSize(find.byType(RemindersEmptyArt));

      await pumpApp(
        tester,
        const RemindersEmptyArt(),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.getSize(find.byType(RemindersEmptyArt)), normal);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The brand-coloured bell tile, found by its glyph.
Finder _bell() => find
    .ancestor(
      of: find.byWidgetPredicate(
        (w) => w is StrokeIcon && w.glyph == StrokeGlyph.navReminders,
      ),
      matching: find.byType(DecoratedBox),
    )
    .first;

/// The three mock text bars on the paper, in order.
///
/// The bar itself, not the [FractionallySizedBox] around it: that box is
/// full-width in both directions and only *places* the bar inside itself, so
/// measuring the box would see no alignment at all. It is `_TextLine`'s own
/// box and the only one in the drawing — the private class cannot be named
/// from here, so this is how its child is reached.
Finder _textLines() => find.descendant(
  of: find.byType(FractionallySizedBox),
  matching: find.byType(DecoratedBox),
);
