import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/quick_reminder_date.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/reminders/usecases/complete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/snooze_reminder.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminders.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:war2aty/features/reminders/presentation/models/manual_reminder_seed.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminders_list_screen.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminders_empty_art.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';
import '../../support/ui_audit.dart';

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
    ValueChanged<ManualReminderSeed>? onQuickReminder,
    VoidCallback? onScan,
  }) => BlocProvider<RemindersCubit>(
    create: (_) => RemindersCubit(
      WatchReminders(repository),
      CompleteReminder(repository, scheduler),
      SnoozeReminder(repository, scheduler),
    )..start(),
    child: RemindersListScreen(
      onAddReminder: onAddReminder,
      onOpenReminder: onOpenReminder,
      onQuickReminder: onQuickReminder,
      onScan: onScan,
    ),
  );

  auditScreenLayout('RemindersListScreen', (tester, locale, scaler) {
    repository.emit([
      fakeReminder(alertTimes: [DateTime(2026, 8, 24, 10)]),
      fakeReminder(id: 'r2', status: ReminderStatus.completed),
    ]);
    return pumpApp(
      tester,
      screenUnderTest(),
      locale: locale,
      textScaler: scaler,
    );
  });

  group('RemindersListScreen', () {
    testWidgets('shows a spinner before the database answers', (tester) async {
      await pumpApp(
        tester,
        screenUnderTest(),
        settle: false,
        framesAfterMount: 0,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('always shows the title and add-reminder action', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderListTitle), findsOneWidget);
      // One match: the header button. The empty state no longer carries
      // its own CTA — the header button is always visible above it.
      expect(find.text(ar.reminderAddAction), findsOneWidget);
    });

    testWidgets('shows the empty-library state with nothing saved', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderEmptyTitle), findsOneWidget);
      expect(find.text(ar.reminderEmptySubtitle), findsOneWidget);
    });

    testWidgets('fills the empty library instead of leaving it blank', (
      tester,
    ) async {
      // F29's first complaint: «التذكيرات» with nothing in it was a title and
      // one grey line 80 px down a blank page. Everything asserted here is
      // what now occupies that space.
      await pumpApp(tester, screenUnderTest());

      expect(find.byType(RemindersEmptyArt), findsOneWidget);
      expect(find.text(ar.reminderQuickCreateKicker), findsOneWidget);
      expect(find.text(ar.reminderQuickTomorrow), findsOneWidget);
      expect(find.text(ar.reminderQuickNextWeek), findsOneWidget);
      expect(find.text(ar.reminderQuickEndOfMonth), findsOneWidget);
      expect(find.text(ar.reminderEmptyScanHint), findsOneWidget);
    });

    testWidgets('hides the tabs while nothing is saved at all', (tester) async {
      // Three tabs that each lead to the same nothing are the main reason
      // this screen read as broken (F29, locked decision 5).
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderTabUpcoming), findsNothing);
      expect(find.text(ar.reminderTabMissed), findsNothing);
      expect(find.text(ar.reminderTabCompleted), findsNothing);
    });

    testWidgets('keeps the tabs when only one bucket is empty', (tester) async {
      // The other half of that decision: a user looking at an empty
      // «الفائتة» needs the tabs to get back to «القادمة».
      repository.emit([fakeReminder()]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      expect(find.text(ar.reminderEmptyMissedTitle), findsOneWidget);
      expect(find.text(ar.reminderTabUpcoming), findsOneWidget);
      expect(find.text(ar.reminderTabCompleted), findsOneWidget);
    });

    testWidgets('each quick row carries its own date into the form', (
      tester,
    ) async {
      final seeds = <ManualReminderSeed>[];
      await pumpApp(tester, screenUnderTest(onQuickReminder: seeds.add));

      await tester.tap(find.text(ar.reminderQuickTomorrow));
      await tester.tap(find.text(ar.reminderQuickNextWeek));
      await tester.pumpAndSettle();

      expect(seeds, hasLength(2));
      // Asserted as the gap between two seeds read off the same screen
      // rather than against a date the test computes from its own clock:
      // «بعد أسبوع» is six days past «بكرة», whatever day it is run on, and
      // no reading of `DateTime.now()` here can disagree with the widget's.
      expect(
        seeds[1].eventDate.difference(seeds[0].eventDate).inDays,
        6,
        reason: '${seeds[0]} → ${seeds[1]}',
      );
      for (final seed in seeds) {
        expect(seed.eventMinuteOfDay, kQuickReminderMinuteOfDay);
      }
    });

    testWidgets('offers «صوّر ورقة» only when it has somewhere to send you', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());
      expect(find.text(ar.reminderEmptyScanCta), findsNothing);

      var scans = 0;
      await pumpApp(tester, screenUnderTest(onScan: () => scans++));

      await tester.tap(find.text(ar.reminderEmptyScanCta));
      await tester.pumpAndSettle();

      expect(scans, 1);
    });

    testWidgets('fires onAddReminder from the header button', (tester) async {
      var tapped = 0;
      await pumpApp(tester, screenUnderTest(onAddReminder: () => tapped++));

      await tester.tap(find.text(ar.reminderAddAction));
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

    testWidgets('the filled empty state survives large text too', (
      tester,
    ) async {
      // The state the layout audit above cannot reach — it emits reminders,
      // so the empty library never renders under it. The pane scrolls, so
      // what is checked is that nothing overflows and the first quick row is
      // still on screen rather than pushed under the fold, which is the
      // reason this state is top-anchored instead of centred.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        screenUnderTest(onScan: () {}),
        textScaler: const TextScaler.linear(1.6),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text(ar.reminderQuickTomorrow)).bottom,
        lessThan(640),
      );
    });
  });
}
