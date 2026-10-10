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

    testWidgets('keeps the same composition in both languages', (tester) async {
      // It is a picture, not a line of content — the bell belongs on the
      // same corner however the text around it runs.
      await pumpApp(tester, const RemindersEmptyArt());
      final rtlBell = tester.getRect(_bell());

      await pumpApp(
        tester,
        const RemindersEmptyArt(),
        locale: AppLocalizations.english,
      );

      expect(tester.getRect(_bell()), rtlBell);
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
