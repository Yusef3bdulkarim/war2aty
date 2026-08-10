import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/reminders/usecases/complete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/snooze_reminder.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminders.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminders_list_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
  });
  tearDown(() => repository.dispose());

  Widget screenUnderTest({
    VoidCallback? onAddReminder,
    ValueChanged<String>? onOpenReminder,
  }) => BlocProvider<RemindersCubit>(
    create: (_) => RemindersCubit(
      WatchReminders(repository),
      CompleteReminder(repository, scheduler),
      SnoozeReminder(repository, scheduler),
    )..start(),
    child: RemindersListScreen(
      onAddReminder: onAddReminder,
      onOpenReminder: onOpenReminder,
    ),
  );

  group('RemindersListScreen', () {
    testWidgets('shows a spinner before the database answers', (tester) async {
      await pumpApp(tester, screenUnderTest(), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('always shows the title and add-reminder action', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderListTitle), findsOneWidget);
      // Two matches while the library is empty: the header button and the
      // empty state's own call to action share the same label.
      expect(find.text(ar.reminderAddAction), findsWidgets);
    });

    testWidgets('shows the empty-library state with nothing saved', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderEmptyTitle), findsOneWidget);
      expect(find.text(ar.reminderEmptySubtitle), findsOneWidget);
    });

    testWidgets('fires onAddReminder from the header button', (tester) async {
      var tapped = 0;
      await pumpApp(tester, screenUnderTest(onAddReminder: () => tapped++));

      await tester.tap(find.text(ar.reminderAddAction).first);
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('says so when the list could not be read', (tester) async {
      repository.emitFailure();

      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderListErrorTitle), findsOneWidget);
      expect(find.text(ar.reminderEmptyTitle), findsNothing);
    });

    testWidgets('lists every upcoming reminder by default', (tester) async {
      final future = DateTime.now().toUtc().add(const Duration(days: 2));
      repository.emit([
        fakeReminder(title: 'فاتورة الكهرباء', alertTimes: [future]),
      ]);

      await pumpApp(tester, screenUnderTest());

      expect(find.text('فاتورة الكهرباء'), findsOneWidget);
      expect(find.text(ar.reminderEmptyTitle), findsNothing);
    });

    testWidgets('switches to the missed bucket on tab tap', (tester) async {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 2));
      repository.emit([
        fakeReminder(title: 'موعد فات', alertTimes: [past]),
      ]);

      await pumpApp(tester, screenUnderTest());
      expect(find.text('موعد فات'), findsNothing);

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      expect(find.text('موعد فات'), findsOneWidget);
    });

    testWidgets('shows the missed tab\'s own empty state', (tester) async {
      repository.emit([fakeReminder()]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      expect(find.text(ar.reminderEmptyMissedTitle), findsOneWidget);
    });

    testWidgets('shows the completed tab\'s own empty state', (tester) async {
      repository.emit([fakeReminder()]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabCompleted));
      await tester.pumpAndSettle();

      expect(find.text(ar.reminderEmptyCompletedTitle), findsOneWidget);
    });

    testWidgets('opens a reminder when its card is tapped', (tester) async {
      repository.emit([fakeReminder(id: 'rem-9', title: 'فاتورة الكهرباء')]);
      String? opened;

      await pumpApp(
        tester,
        screenUnderTest(onOpenReminder: (id) => opened = id),
      );

      await tester.tap(find.text('فاتورة الكهرباء'));
      await tester.pumpAndSettle();

      expect(opened, 'rem-9');
    });

    testWidgets('lists completed reminders under their own tab', (
      tester,
    ) async {
      repository.emit([
        fakeReminder(
          id: 'done',
          title: 'خلصت',
          status: ReminderStatus.completed,
        ),
      ]);

      await pumpApp(tester, screenUnderTest());
      await tester.tap(find.text(ar.reminderTabCompleted));
      await tester.pumpAndSettle();

      expect(find.text('خلصت'), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        screenUnderTest(),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.reminderListTitle), findsOneWidget);
      expect(find.text(en.reminderEmptyTitle), findsOneWidget);
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final future = DateTime.now().toUtc().add(const Duration(days: 2));
      repository.emit([
        fakeReminder(
          title: 'فاتورة الكهرباء لشهر أغسطس لشقة الدور الخامس',
          alertTimes: [future],
        ),
      ]);

      await pumpApp(
        tester,
        screenUnderTest(),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
