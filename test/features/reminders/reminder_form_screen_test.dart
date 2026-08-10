import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/request_notification_permission.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_cubit.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_from_document_args.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminder_form_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  late FakeRemindersRepository repository;
  late CreateReminderFromDocumentDate createFromDocumentDate;
  late CreateManualReminder createManual;
  late GetNotificationPermission getNotificationPermission;
  late RequestNotificationPermission requestNotificationPermission;

  setUp(() {
    repository = FakeRemindersRepository();
    final scheduler = FakeReminderScheduler();
    createFromDocumentDate = CreateReminderFromDocumentDate(
      repository,
      scheduler,
    );
    createManual = CreateManualReminder(repository, scheduler);
    final notificationPermissionRepository =
        FakeNotificationPermissionRepository();
    getNotificationPermission = GetNotificationPermission(
      notificationPermissionRepository,
    );
    requestNotificationPermission = RequestNotificationPermission(
      notificationPermissionRepository,
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    ReminderFormCubit cubit, {
    ValueChanged<Reminder>? onSaved,
    VoidCallback? onClose,
  }) => pumpApp(
    tester,
    BlocProvider<ReminderFormCubit>.value(
      value: cubit,
      child: ReminderFormScreen(
        screenTitle: ar.reminderCreateScreenTitle,
        onSaved: onSaved,
        onClose: onClose,
      ),
    ),
  );

  testWidgets('shows the prefilled title and the paper\'s event date/time', (
    tester,
  ) async {
    final cubit = ReminderFormCubit.fromDocument(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
      args: ReminderFromDocumentArgs(
        title: 'دفع فاتورة الكهرباء',
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: 600,
      ),
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit);

    expect(find.text('دفع فاتورة الكهرباء'), findsOneWidget);
    expect(find.textContaining('10:00'), findsOneWidget);
  });

  testWidgets('shows the linked document when one is set', (tester) async {
    final cubit = ReminderFormCubit.fromDocument(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
      args: ReminderFromDocumentArgs(
        documentId: 'doc-1',
        documentTitle: 'فاتورة كهرباء شهر أغسطس',
        title: 'دفع فاتورة الكهرباء',
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: 600,
      ),
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit);

    expect(find.text('فاتورة كهرباء شهر أغسطس'), findsOneWidget);
  });

  testWidgets('the save button is disabled until the manual form is complete', (
    tester,
  ) async {
    final cubit = ReminderFormCubit.manual(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, ar.reminderSaveAction),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'the manual form shows date/time pickers, not the read-only card',
    (tester) async {
      final cubit = ReminderFormCubit.manual(
        createFromDocumentDate: createFromDocumentDate,
        createManual: createManual,
        getNotificationPermission: getNotificationPermission,
        requestNotificationPermission: requestNotificationPermission,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);

      expect(find.text(ar.reminderDatePickHint), findsOneWidget);
      expect(find.text(ar.reminderTimePickHint), findsOneWidget);
    },
  );

  testWidgets(
    'picking a date and time enables save once a title and an alert exist',
    (tester) async {
      final cubit = ReminderFormCubit.manual(
        createFromDocumentDate: createFromDocumentDate,
        createManual: createManual,
        getNotificationPermission: getNotificationPermission,
        requestNotificationPermission: requestNotificationPermission,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit);
      // The title field is the first of the form's two `TextField`s (title,
      // then note).
      await tester.enterText(find.byType(TextField).first, 'تذكير جديد');
      cubit.setEventDate(DateTime(2026, 9));
      cubit.setEventMinuteOfDay(9 * 60);
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, ar.reminderSaveAction),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('saving calls onSaved with the written reminder', (tester) async {
    repository.createOutcome = Ok(fakeReminder());
    Reminder? saved;
    final cubit = ReminderFormCubit.fromDocument(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
      args: ReminderFromDocumentArgs(
        title: 'دفع فاتورة الكهرباء',
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: 600,
      ),
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit, onSaved: (r) => saved = r);
    await tester.tap(find.text(ar.reminderSaveAction));
    await tester.pumpAndSettle();

    expect(saved?.id, 'r1');
  });

  testWidgets('a save failure shows feedback and keeps the form usable', (
    tester,
  ) async {
    repository.createOutcome = const Err(LocalDatabaseFailure());
    final cubit = ReminderFormCubit.fromDocument(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
      args: ReminderFromDocumentArgs(
        title: 'دفع فاتورة الكهرباء',
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: 600,
      ),
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit);
    await tester.tap(find.text(ar.reminderSaveAction));
    await tester.pumpAndSettle();

    expect(find.text(ar.reminderActionFailedFeedback), findsOneWidget);
    // The form itself is still there, ready to try again — not swapped for
    // a dead end.
    expect(find.text('دفع فاتورة الكهرباء'), findsOneWidget);
  });

  testWidgets('cancel calls onClose', (tester) async {
    var closed = false;
    final cubit = ReminderFormCubit.manual(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit, onClose: () => closed = true);
    await tester.tap(find.text(ar.actionCancel));
    await tester.pump();

    expect(closed, isTrue);
  });
}
