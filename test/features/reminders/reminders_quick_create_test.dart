import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/quick_reminder_date.dart';
import 'package:war2aty/core/widgets/forward_chevron.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminders_quick_create.dart';

import '../../support/pump_app.dart';

Widget _wrapped(Widget child) => Scaffold(body: child);

const String _tomorrowDate = '16 أكتوبر 2026 — 9:00 صباحًا';
const String _nextWeekDate = '22 أكتوبر 2026 — 9:00 صباحًا';
const String _endOfMonthDate = '31 أكتوبر 2026 — 9:00 صباحًا';

/// Fixed slots, so every date line below is a literal rather than a value
/// recomputed by the very code it is meant to pin. The arithmetic that
/// produces them in production has its own 24 tests
/// (`test/core/reminders/quick_reminder_date_test.dart`).
List<QuickReminderSlot> _slots() => [
  QuickReminderSlot(
    kind: QuickReminderDate.tomorrow,
    eventDate: DateTime(2026, 10, 16),
    eventMinuteOfDay: kQuickReminderMinuteOfDay,
  ),
  QuickReminderSlot(
    kind: QuickReminderDate.nextWeek,
    eventDate: DateTime(2026, 10, 22),
    eventMinuteOfDay: kQuickReminderMinuteOfDay,
  ),
  QuickReminderSlot(
    kind: QuickReminderDate.endOfMonth,
    eventDate: DateTime(2026, 10, 31),
    eventMinuteOfDay: kQuickReminderMinuteOfDay,
  ),
];

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('RemindersQuickCreate', () {
    testWidgets('names the three dates and writes each one out', (
      tester,
    ) async {
      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
      );

      expect(find.text(ar.reminderQuickTomorrow), findsOneWidget);
      expect(find.text(ar.reminderQuickNextWeek), findsOneWidget);
      expect(find.text(ar.reminderQuickEndOfMonth), findsOneWidget);

      // The promise of the row is the date it resolves to — written exactly
      // the way the form the row opens writes it, from `formatDocumentDate`
      // + `formatWallClockTime`. If either side drifts the user reads one
      // date on the list and a different one in the form.
      expect(find.text(_tomorrowDate), findsOneWidget);
      expect(find.text(_nextWeekDate), findsOneWidget);
      expect(find.text(_endOfMonthDate), findsOneWidget);
    });

    testWidgets('reports the slot that was tapped, and only it', (
      tester,
    ) async {
      final tapped = <QuickReminderSlot>[];
      final slots = _slots();

      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: slots, onSelected: tapped.add)),
      );

      await tester.tap(find.text(ar.reminderQuickNextWeek));
      await tester.pumpAndSettle();

      // Compared by value, not by count: a row wired to its neighbour's slot
      // would silently create a reminder for the wrong day.
      expect(tapped, [slots[1]]);
    });

    testWidgets('each row reads as one button naming its own date', (
      tester,
    ) async {
      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
      );

      // One node per row rather than a name node and a date node: a user on
      // a screen reader should learn what the row does in a single swipe.
      for (final (name, date) in [
        (ar.reminderQuickTomorrow, _tomorrowDate),
        (ar.reminderQuickNextWeek, _nextWeekDate),
        (ar.reminderQuickEndOfMonth, _endOfMonthDate),
      ]) {
        expect(
          tester.getSemantics(find.text(name)),
          isSemantics(
            isButton: true,
            hasTapAction: true,
            label: '$name. $date',
          ),
        );
      }
    });

    testWidgets('the calendar mark is decoration, not an announcement', (
      tester,
    ) async {
      // The row's own label already says it is a date; «تقويم» read before
      // it would only be noise.
      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
      );

      final icons = tester.widgetList<StrokeIcon>(find.byType(StrokeIcon));

      expect(icons.where((i) => i.glyph == StrokeGlyph.calendar), hasLength(3));
      for (final icon in icons) {
        expect(icon.semanticLabel, isNull);
      }
    });

    testWidgets('mirrors its copy and its chevrons in English', (tester) async {
      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
        locale: AppLocalizations.english,
      );
      final ltrChevron = tester.getRect(_chevron()).center.dx;
      final ltrIcon = tester.getRect(_calendarBox()).center.dx;

      expect(find.text(en.reminderQuickTomorrow), findsOneWidget);
      expect(find.text('16 October 2026 — 9:00 AM'), findsOneWidget);
      // The chevron sits at the far end of the line: past the leading icon
      // box in English, before it in Arabic. That the glyph itself *turns
      // around* is `ForwardChevron`'s job and its own test's — four rows in
      // this app once pointed backwards in English because each drew the
      // raw glyph (F27-T15), so what is pinned here is that these rows go
      // through the shared widget rather than drawing their own.
      expect(ltrChevron, greaterThan(ltrIcon));
      expect(find.byType(ForwardChevron), findsNWidgets(3));

      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
      );

      expect(tester.getRect(_chevron()).center.dx, lessThan(ltrIcon));
    });

    testWidgets('grows instead of overflowing at 1.6× text', (tester) async {
      // This is why concept D was picked over the four-row explainer: the row
      // simply gets taller. On a 390-wide phone at 1.6× neither line even
      // needs to wrap — the narrow case that does is the next test.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
      );
      final normal = tester.getSize(_row()).height;

      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
        textScaler: const TextScaler.linear(1.6),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(_row()).height, greaterThan(normal));
      // Still readable: a row that grew while clipping its own text would
      // pass the height check and fail the user.
      expect(find.text(ar.reminderQuickTomorrow), findsOneWidget);
      expect(find.text(_tomorrowDate), findsOneWidget);
    });

    testWidgets('wraps its date on the narrowest phone at 2× text', (
      tester,
    ) async {
      // The worst case the app allows: the smallest phone it targets at the
      // top of the text-size setting. Here the date genuinely does not fit
      // beside the icon and the chevron, so the row has to let it wrap — a
      // fixed-width text column overflows instead, and a `RenderFlex`
      // overflow is an exception in a test and a yellow bar on the device.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_tomorrowDate), findsOneWidget);
      // Two lines of a 13 px caption at 2× — proof it wrapped rather than
      // being cut off at the edge of the row.
      expect(tester.getSize(find.text(_tomorrowDate)).height, greaterThan(40));
    });

    testWidgets('keeps a tappable height at 1× text', (tester) async {
      // The prototype's 56 px floor, which is what keeps the three rows
      // comfortable for the older users this app is built for. Measured on
      // the rendered row rather than declared as a `minHeight`: the icon box
      // and the padding already carry it past 56, so a constraint would
      // never bind — this catches the padding or the box being shrunk out
      // from under it.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: _slots(), onSelected: (_) {})),
      );

      expect(tester.getSize(_row()).height, greaterThanOrEqualTo(56));
    });

    testWidgets('draws what it is handed, in the order it is handed', (
      tester,
    ) async {
      // It renders its argument rather than reaching for the clock itself,
      // which is what leaves the caller owning the single clock read — and
      // what lets every date above be a literal.
      await pumpApp(
        tester,
        _wrapped(
          RemindersQuickCreate(
            slots: _slots().take(2).toList(),
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.byType(InkWell), findsNWidgets(2));
      expect(find.text(ar.reminderQuickEndOfMonth), findsNothing);
      expect(
        tester.getRect(find.text(ar.reminderQuickTomorrow)).top,
        lessThan(tester.getRect(find.text(ar.reminderQuickNextWeek)).top),
      );
    });

    testWidgets('consumes the real quick-date helper', (tester) async {
      // The widget and the arithmetic are tested apart; this is the one case
      // that puts them together, so a slot kind the label switch forgot
      // cannot reach the screen as a blank row.
      final slots = quickReminderSlots(
        // Noon in Cairo on summer time — the same instant the helper's own
        // tests use for an ordinary mid-month day.
        now: DateTime.utc(2026, 10, 15, 9),
      );

      await pumpApp(
        tester,
        _wrapped(RemindersQuickCreate(slots: slots, onSelected: (_) {})),
      );

      expect(find.byType(InkWell), findsNWidgets(3));
      expect(find.text(_tomorrowDate), findsOneWidget);
      expect(find.text(_nextWeekDate), findsOneWidget);
      expect(find.text(_endOfMonthDate), findsOneWidget);
    });
  });
}

/// The first row's tappable box.
Finder _row() => find.byType(InkWell).first;

/// The first row's leading icon box — the calendar glyph's own container.
Finder _calendarBox() => find
    .ancestor(
      of: find
          .byWidgetPredicate(
            (w) => w is StrokeIcon && w.glyph == StrokeGlyph.calendar,
          )
          .first,
      matching: find.byType(DecoratedBox),
    )
    .first;

/// The first row's chevron.
Finder _chevron() => find
    .byWidgetPredicate(
      (w) => w is StrokeIcon && w.glyph == StrokeGlyph.chevronForward,
    )
    .first;
