import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminder_list_item.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

Widget _wrapped(Widget child) => Scaffold(body: child);

void main() {
  const ar = ArStrings();

  group('ReminderListItem', () {
    testWidgets('shows the title', (tester) async {
      await pumpApp(
        tester,
        _wrapped(
          ReminderListItem(reminder: fakeReminder(title: 'فاتورة الكهرباء')),
        ),
      );

      expect(find.text('فاتورة الكهرباء'), findsOneWidget);
    });

    testWidgets('shows «قادم» for a pending reminder with a future alert', (
      tester,
    ) async {
      final future = DateTime.now().toUtc().add(const Duration(days: 3));

      await pumpApp(
        tester,
        _wrapped(
          ReminderListItem(reminder: fakeReminder(alertTimes: [future])),
        ),
      );

      expect(find.text(ar.reminderStatusUpcoming), findsOneWidget);
    });

    testWidgets('shows «فائت» once every alert is in the past', (tester) async {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 3));

      await pumpApp(
        tester,
        _wrapped(ReminderListItem(reminder: fakeReminder(alertTimes: [past]))),
      );

      expect(find.text(ar.reminderStatusMissed), findsOneWidget);
    });

    testWidgets('shows «تم» for a completed reminder', (tester) async {
      await pumpApp(
        tester,
        _wrapped(
          ReminderListItem(
            reminder: fakeReminder(status: ReminderStatus.completed),
          ),
        ),
      );

      expect(find.text(ar.reminderStatusCompleted), findsOneWidget);
    });

    testWidgets('is inert with no destination yet', (tester) async {
      await pumpApp(
        tester,
        _wrapped(
          ReminderListItem(reminder: fakeReminder(title: 'فاتورة الكهرباء')),
        ),
      );

      expect(
        tester.getSemantics(find.text('فاتورة الكهرباء')),
        isSemantics(hasTapAction: false),
      );
    });

    testWidgets('opens the reminder once a destination is wired', (
      tester,
    ) async {
      var tapped = 0;

      await pumpApp(
        tester,
        _wrapped(
          ReminderListItem(reminder: fakeReminder(), onTap: () => tapped++),
        ),
      );

      await tester.tap(find.byType(ReminderListItem));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('draws no action row until F09-T12 wires one', (tester) async {
      await pumpApp(
        tester,
        _wrapped(ReminderListItem(reminder: fakeReminder())),
      );

      expect(find.text(ar.reminderCompleteAction), findsNothing);
      expect(find.text(ar.reminderSnoozeAction), findsNothing);
    });

    testWidgets('draws only the actions it is given', (tester) async {
      await pumpApp(
        tester,
        _wrapped(ReminderListItem(reminder: fakeReminder(), onComplete: () {})),
      );

      expect(find.text(ar.reminderCompleteAction), findsOneWidget);
      expect(find.text(ar.reminderSnoozeAction), findsNothing);
    });

    testWidgets('draws no actions on a completed reminder', (tester) async {
      await pumpApp(
        tester,
        _wrapped(
          ReminderListItem(
            reminder: fakeReminder(status: ReminderStatus.completed),
            onComplete: () {},
            onSnooze: () {},
          ),
        ),
      );

      expect(find.text(ar.reminderCompleteAction), findsNothing);
      expect(find.text(ar.reminderSnoozeAction), findsNothing);
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        _wrapped(
          ReminderListItem(
            reminder: fakeReminder(
              title: 'فاتورة الكهرباء لشهر أغسطس لشقة الدور الخامس',
            ),
            onComplete: () {},
            onSnooze: () {},
          ),
        ),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
