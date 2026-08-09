import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminder_date_time_pickers.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  // Needs a Material ancestor for its InkWell rows, which the real screen's
  // own Scaffold already provides.
  Widget scaffolded(Widget child) => Scaffold(body: child);

  testWidgets('shows placeholders when nothing is picked yet', (tester) async {
    await pumpApp(
      tester,
      scaffolded(
        ReminderDateTimePickers(
          eventDate: null,
          eventMinuteOfDay: null,
          onDatePicked: (_) {},
          onTimePicked: (_) {},
        ),
      ),
    );

    expect(find.text(ar.reminderDatePickHint), findsOneWidget);
    expect(find.text(ar.reminderTimePickHint), findsOneWidget);
  });

  testWidgets('shows the chosen date and time once both are set', (
    tester,
  ) async {
    await pumpApp(
      tester,
      scaffolded(
        ReminderDateTimePickers(
          eventDate: DateTime(2026, 9),
          eventMinuteOfDay: 9 * 60,
          onDatePicked: (_) {},
          onTimePicked: (_) {},
        ),
      ),
    );

    expect(find.text(ar.reminderDatePickHint), findsNothing);
    expect(find.text(ar.reminderTimePickHint), findsNothing);
    expect(find.textContaining('9:00'), findsOneWidget);
  });

  testWidgets('tapping the date row opens the date picker', (tester) async {
    await pumpApp(
      tester,
      scaffolded(
        ReminderDateTimePickers(
          eventDate: null,
          eventMinuteOfDay: null,
          onDatePicked: (_) {},
          onTimePicked: (_) {},
        ),
      ),
    );

    await tester.tap(find.text(ar.reminderDatePickHint));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('tapping the time row opens the time picker', (tester) async {
    await pumpApp(
      tester,
      scaffolded(
        ReminderDateTimePickers(
          eventDate: null,
          eventMinuteOfDay: null,
          onDatePicked: (_) {},
          onTimePicked: (_) {},
        ),
      ),
    );

    await tester.tap(find.text(ar.reminderTimePickHint));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
