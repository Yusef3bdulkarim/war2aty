import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/alert_time_offset.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_state.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_alert_draft.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_from_document_args.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminder_form_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

// F09-T08: up to 3 alerts, add and remove, through the real screen + cubit
// (the widget-level add/remove/cap behaviour is covered on its own in
// reminder_alert_list_section_test.dart — this exercises the whole flow).
void main() {
  const ar = ArStrings();
  late FakeRemindersRepository repository;
  late CreateReminderFromDocumentDate createFromDocumentDate;
  late CreateManualReminder createManual;

  setUp(() {
    repository = FakeRemindersRepository();
    createFromDocumentDate = CreateReminderFromDocumentDate(repository);
    createManual = CreateManualReminder(repository);
  });

  final eventInstant = DateTime.utc(2026, 8, 25, 8); // 10:00 Cairo.

  ReminderFormCubit buildCubit() => ReminderFormCubit.fromDocument(
    createFromDocumentDate: createFromDocumentDate,
    createManual: createManual,
    args: ReminderFromDocumentArgs(
      title: 'دفع فاتورة الكهرباء',
      eventDate: DateTime(2026, 8, 25),
      eventMinuteOfDay: 600,
    ),
  );

  ReminderAlertDraft draftFor(AlertTimeOffset offset) =>
      ReminderAlertDraft(time: offset.applyTo(eventInstant), offset: offset);

  Future<void> pumpScreen(WidgetTester tester, ReminderFormCubit cubit) =>
      pumpApp(
        tester,
        BlocProvider<ReminderFormCubit>.value(
          value: cubit,
          child: ReminderFormScreen(screenTitle: ar.reminderCreateScreenTitle),
        ),
      );

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('adding through the "add another" flow reaches the cap of 3', (
    tester,
  ) async {
    final cubit = buildCubit();
    addTearDown(cubit.close);
    await pumpScreen(tester, cubit);

    // Starts with the default "a day before" alert (F09-T05); add the two
    // remaining offsets to reach the cap.
    expect((cubit.state as ReminderFormEditing).alerts, hasLength(1));

    await tapVisible(tester, find.text(ar.reminderAddAnotherAlert));
    await tapVisible(tester, find.text(ar.reminderAlertOffsetTwoHours));
    expect((cubit.state as ReminderFormEditing).alerts, hasLength(2));

    await tapVisible(tester, find.text(ar.reminderAddAnotherAlert));
    await tapVisible(tester, find.text(ar.reminderAlertOffsetThreeDays));
    expect((cubit.state as ReminderFormEditing).alerts, hasLength(3));

    // The cap is reached — the design gives no button that would do nothing.
    expect(find.text(ar.reminderAddAnotherAlert), findsNothing);
  });

  testWidgets('removing one below the cap brings the add button back', (
    tester,
  ) async {
    final cubit = buildCubit()
      ..addAlert(draftFor(AlertTimeOffset.twoHoursBefore))
      ..addAlert(draftFor(AlertTimeOffset.threeDaysBefore));
    addTearDown(cubit.close);
    await pumpScreen(tester, cubit);
    expect((cubit.state as ReminderFormEditing).alerts, hasLength(3));
    expect(find.text(ar.reminderAddAnotherAlert), findsNothing);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect((cubit.state as ReminderFormEditing).alerts, hasLength(2));
    expect(find.text(ar.reminderAddAnotherAlert), findsOneWidget);
  });

  test('every alert time is written when the reminder is saved', () async {
    final cubit = buildCubit()
      ..addAlert(draftFor(AlertTimeOffset.twoHoursBefore))
      ..addAlert(draftFor(AlertTimeOffset.threeDaysBefore));
    addTearDown(cubit.close);

    await cubit.save();

    expect(repository.lastCreatedAlertTimes, hasLength(3));
  });
}
