import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_state.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_from_document_args.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminder_form_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

// F09-T06: a from-document reminder whose paper gave a date but no time.
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

  ReminderFormCubit buildNoTimeCubit() => ReminderFormCubit.fromDocument(
    createFromDocumentDate: createFromDocumentDate,
    createManual: createManual,
    args: ReminderFromDocumentArgs(
      title: 'تجديد الرخصة',
      eventDate: DateTime(2026, 8, 25),
    ),
  );

  testWidgets('shows the missing-time warning and a 10 AM suggestion', (
    tester,
  ) async {
    final cubit = buildNoTimeCubit();
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<ReminderFormCubit>.value(
        value: cubit,
        child: ReminderFormScreen(screenTitle: ar.reminderCreateScreenTitle),
      ),
    );

    expect(find.text(ar.reminderMissingEventTimeWarning), findsOneWidget);
    expect(
      find.text(ar.reminderSuggestedAlertTime('10:00 ${ar.timeAm}')),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping the suggestion adds a 10 AM alert and hides the warning',
    (tester) async {
      final cubit = buildNoTimeCubit();
      addTearDown(cubit.close);

      await pumpApp(
        tester,
        BlocProvider<ReminderFormCubit>.value(
          value: cubit,
          child: ReminderFormScreen(screenTitle: ar.reminderCreateScreenTitle),
        ),
      );

      final suggestion = find.text(
        ar.reminderSuggestedAlertTime('10:00 ${ar.timeAm}'),
      );
      await tester.ensureVisible(suggestion);
      await tester.tap(suggestion);
      await tester.pump();

      expect(find.text(ar.reminderMissingEventTimeWarning), findsNothing);
      final state = cubit.state as ReminderFormEditing;
      expect(state.alerts, hasLength(1));
    },
  );

  testWidgets('the missing-time picker offers only a custom time', (
    tester,
  ) async {
    final cubit = buildNoTimeCubit();
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<ReminderFormCubit>.value(
        value: cubit,
        child: ReminderFormScreen(screenTitle: ar.reminderCreateScreenTitle),
      ),
    );

    final addAnother = find.text(ar.reminderAddAnotherAlert);
    await tester.ensureVisible(addAnother);
    await tester.tap(addAnother);
    await tester.pumpAndSettle();

    expect(find.text(ar.reminderAlertOffsetCustom), findsOneWidget);
    expect(find.text(ar.reminderAlertOffsetOneDay), findsNothing);
  });

  testWidgets('a manual reminder with no date/time yet shows no warning', (
    tester,
  ) async {
    final cubit = ReminderFormCubit.manual(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
    );
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<ReminderFormCubit>.value(
        value: cubit,
        child: ReminderFormScreen(screenTitle: ar.reminderAddAction),
      ),
    );

    expect(find.text(ar.reminderMissingEventTimeWarning), findsNothing);
  });
}
