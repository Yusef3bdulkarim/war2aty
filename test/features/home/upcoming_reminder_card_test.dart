import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/upcoming_reminder.dart';
import 'package:war2aty/core/widgets/skeleton.dart';
import 'package:war2aty/features/home/presentation/cubit/home_state.dart';
import 'package:war2aty/features/home/presentation/widgets/upcoming_reminder_card.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  final now = DateTime.utc(2026, 7, 22, 8);
  final dueTomorrow = DateTime.utc(2026, 7, 23, 8);

  Widget cardFor(
    ReminderSection section, {
    ValueChanged<UpcomingReminder>? onOpen,
  }) => UpcomingReminderCard(section: section, onOpen: onOpen, now: now);

  group('visibility', () {
    test('hidden while loading', () {
      expect(UpcomingReminderCard.isVisible(const ReminderLoading()), isFalse);
    });

    test('hidden when it could not be read', () {
      expect(
        UpcomingReminderCard.isVisible(
          const ReminderUnavailable(LocalDatabaseFailure()),
        ),
        isFalse,
      );
    });

    test('hidden when nothing is scheduled', () {
      expect(
        UpcomingReminderCard.isVisible(const ReminderAvailable(null)),
        isFalse,
      );
    });

    test('shown once a reminder is due', () {
      expect(
        UpcomingReminderCard.isVisible(ReminderAvailable(reminderWith())),
        isTrue,
      );
    });
  });

  group('UpcomingReminderCard', () {
    testWidgets('shows a placeholder card while the database is read', (
      tester,
    ) async {
      await pumpApp(tester, cardFor(const ReminderLoading()), settle: false);

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.bySemanticsLabel(ar.stateLoading), findsOneWidget);
    });

    testWidgets('the placeholder gives way to the real card', (tester) async {
      await pumpApp(
        tester,
        cardFor(ReminderAvailable(reminderWith(dueAt: dueTomorrow))),
      );

      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('دفع فاتورة الكهرباء'), findsOneWidget);
    });

    testWidgets('renders nothing when nothing is scheduled', (tester) async {
      await pumpApp(tester, cardFor(const ReminderAvailable(null)));

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the heading, the title and when it is due', (
      tester,
    ) async {
      await pumpApp(
        tester,
        cardFor(ReminderAvailable(reminderWith(dueAt: dueTomorrow))),
      );

      expect(find.text(ar.homeUpcomingReminderTitle), findsOneWidget);
      expect(find.text('دفع فاتورة الكهرباء'), findsOneWidget);
      expect(find.text('بكرة، الساعة 10:00 صباحًا'), findsOneWidget);
    });

    testWidgets('marks the card with the bell glyph', (tester) async {
      await pumpApp(tester, cardFor(ReminderAvailable(reminderWith())));

      final icon = tester.widget<StrokeIcon>(find.byType(StrokeIcon));
      expect(icon.glyph, StrokeGlyph.navReminders);
    });

    testWidgets('the accent stripe follows the reading direction', (
      tester,
    ) async {
      BorderDirectional stripeOf(WidgetTester tester) {
        final ink = tester.widget<Ink>(find.byType(Ink));
        return (ink.decoration! as BoxDecoration).border! as BorderDirectional;
      }

      await pumpApp(tester, cardFor(ReminderAvailable(reminderWith())));

      // The design draws it on the right of an RTL page — that is the leading
      // edge, so it must be a *directional* border rather than a fixed side,
      // or it would sit on the wrong edge in English.
      final border = stripeOf(tester);
      expect(border.start.width, 4);
      expect(border.end, BorderSide.none);
    });

    testWidgets('hides "view" until the reminder screen exists', (
      tester,
    ) async {
      await pumpApp(tester, cardFor(ReminderAvailable(reminderWith())));

      expect(find.text(ar.actionView), findsNothing);
    });

    testWidgets('opens the reminder once it has a destination', (tester) async {
      UpcomingReminder? opened;
      final reminder = reminderWith();

      await pumpApp(
        tester,
        cardFor(ReminderAvailable(reminder), onOpen: (r) => opened = r),
      );

      expect(find.text(ar.actionView), findsOneWidget);
      await tester.tap(find.text(reminder.title));
      await tester.pumpAndSettle();

      expect(opened, reminder);
    });

    testWidgets('reads as one sentence, and can be activated', (tester) async {
      final reminder = reminderWith(dueAt: dueTomorrow);

      await pumpApp(
        tester,
        cardFor(ReminderAvailable(reminder), onOpen: (_) {}),
      );

      expect(
        tester.getSemantics(find.text(reminder.title)),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'دفع فاتورة الكهرباء. بكرة، الساعة 10:00 صباحًا',
        ),
      );
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        cardFor(
          ReminderAvailable(
            reminderWith(title: 'Pay the electricity bill', dueAt: dueTomorrow),
          ),
        ),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.homeUpcomingReminderTitle), findsOneWidget);
      expect(find.text('Tomorrow at 10:00 AM'), findsOneWidget);
    });

    testWidgets('survives large text and a long title', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        cardFor(
          ReminderAvailable(
            reminderWith(
              title: 'دفع فاتورة الكهرباء عن شهر أغسطس قبل آخر موعد للسداد',
            ),
          ),
          onOpen: (_) {},
        ),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
