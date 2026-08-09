import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
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

  setUp(() {
    repository = FakeRemindersRepository();
    createFromDocumentDate = CreateReminderFromDocumentDate(repository);
    createManual = CreateManualReminder(repository);
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
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, ar.reminderSaveAction),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('saving calls onSaved with the written reminder', (tester) async {
    repository.createOutcome = Ok(fakeReminder());
    Reminder? saved;
    final cubit = ReminderFormCubit.fromDocument(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
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

  testWidgets('cancel calls onClose', (tester) async {
    var closed = false;
    final cubit = ReminderFormCubit.manual(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
    );
    addTearDown(cubit.close);

    await pumpScreen(tester, cubit, onClose: () => closed = true);
    await tester.tap(find.text(ar.actionCancel));
    await tester.pump();

    expect(closed, isTrue);
  });
}
