import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/watch_document.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/reminders/usecases/complete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/delete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/snooze_reminder.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminder.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_details_cubit.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminder_details_screen.dart';

import '../../support/fakes.dart';
import '../../support/mirrored_icon.dart';
import '../../support/pump_app.dart';

// F09-T12: «تفاصيل التذكير».
void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakeRemindersRepository remindersRepository;
  late FakeDocumentsRepository documentsRepository;
  late FakeReminderScheduler scheduler;
  late ReminderDetailsCubit cubit;

  setUp(() {
    remindersRepository = FakeRemindersRepository();
    documentsRepository = FakeDocumentsRepository();
    scheduler = FakeReminderScheduler();
    cubit = ReminderDetailsCubit(
      WatchReminder(remindersRepository),
      WatchDocument(documentsRepository),
      CompleteReminder(remindersRepository, scheduler),
      SnoozeReminder(remindersRepository, scheduler),
      DeleteReminder(remindersRepository, scheduler),
    );
  });
  tearDown(() {
    cubit.close();
    remindersRepository.dispose();
    documentsRepository.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onClose,
    ValueChanged<String>? onOpenDocument,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
    bool settle = true,
  }) => pumpApp(
    tester,
    BlocProvider<ReminderDetailsCubit>.value(
      value: cubit,
      child: ReminderDetailsScreen(
        onClose: onClose,
        onOpenDocument: onOpenDocument,
      ),
    ),
    locale: locale,
    textScaler: textScaler,
    settle: settle,
  );

  group('ReminderDetailsScreen', () {
    testWidgets('shows a spinner before the database answers', (tester) async {
      await pumpScreen(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the reminder once the database answers', (tester) async {
      remindersRepository.emitReminder(
        'r1',
        fakeReminder(title: 'فاتورة الكهرباء'),
      );
      cubit.start('r1');

      await pumpScreen(tester);

      expect(find.text(ar.reminderDetailsTitle), findsOneWidget);
      expect(find.text('فاتورة الكهرباء'), findsOneWidget);
    });

    testWidgets('the back icon mirrors under English (F12-T03)', (
      tester,
    ) async {
      remindersRepository.emitReminder('r1', fakeReminder());
      cubit.start('r1');

      await pumpScreen(tester);
      expect(
        mirrorScaleX(tester, StrokeGlyph.arrowBack),
        1,
        reason: 'RTL: points right as drawn',
      );

      await pumpScreen(tester, locale: AppLocalizations.english);
      expect(
        mirrorScaleX(tester, StrokeGlyph.arrowBack),
        -1,
        reason: 'LTR: mirrored to point left',
      );
    });

    testWidgets(
      'the linked-document row mirrors its chevron under English (F12-T03)',
      (tester) async {
        remindersRepository.emitReminder(
          'r1',
          fakeReminder(documentId: 'doc-1'),
        );
        documentsRepository.emitDocument(
          savedDocumentWith(title: 'فاتورة كهرباء'),
        );
        cubit.start('r1');

        await pumpScreen(tester);
        expect(
          mirrorScaleX(tester, StrokeGlyph.chevronForward),
          1,
          reason: 'RTL: points left as drawn',
        );

        await pumpScreen(tester, locale: AppLocalizations.english);
        expect(
          mirrorScaleX(tester, StrokeGlyph.chevronForward),
          -1,
          reason: 'LTR: mirrored to point right',
        );
      },
    );

    testWidgets('shows complete/snooze only while pending', (tester) async {
      remindersRepository.emitReminder(
        'r1',
        fakeReminder(status: ReminderStatus.completed),
      );
      cubit.start('r1');

      await pumpScreen(tester);

      expect(find.text(ar.reminderDetailsCompleteAction), findsNothing);
      expect(find.text(ar.reminderDetailsSnoozeAction), findsNothing);
      // Delete stays available whatever the status.
      expect(find.text(ar.reminderDetailsDeleteAction), findsOneWidget);
    });

    testWidgets('shows the description when present', (tester) async {
      remindersRepository.emitReminder(
        'r1',
        Reminder(
          id: 'r1',
          title: 'دفع فاتورة الكهرباء',
          description: 'ملاحظة تفصيلية',
          eventDate: DateTime(2026, 8, 25),
          eventMinuteOfDay: 600,
          status: ReminderStatus.pending,
          isManual: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      cubit.start('r1');

      await pumpScreen(tester);

      expect(find.text('ملاحظة تفصيلية'), findsOneWidget);
    });

    testWidgets('shows a linked document button and fires onOpenDocument', (
      tester,
    ) async {
      remindersRepository.emitReminder('r1', fakeReminder(documentId: 'doc-1'));
      cubit.start('r1');
      documentsRepository.emitDocument(
        savedDocumentWith(title: 'فاتورة كهرباء'),
      );
      String? opened;

      await pumpScreen(tester, onOpenDocument: (id) => opened = id);

      expect(find.text('فاتورة كهرباء'), findsOneWidget);
      await tester.tap(find.text('فاتورة كهرباء'));
      await tester.pumpAndSettle();

      expect(opened, 'doc-1');
    });

    testWidgets('completing shows feedback', (tester) async {
      remindersRepository.emitReminder('r1', fakeReminder());
      cubit.start('r1');

      await pumpScreen(tester);
      await tester.tap(find.text(ar.reminderDetailsCompleteAction));
      await tester.pumpAndSettle();

      expect(find.text(ar.reminderCompletedFeedback), findsOneWidget);
      expect(remindersRepository.lastCompletedId, 'r1');
    });

    testWidgets('deleting requires confirmation, then pops', (tester) async {
      remindersRepository.emitReminder('r1', fakeReminder());
      cubit.start('r1');
      var closed = false;

      await pumpScreen(tester, onClose: () => closed = true);
      await tester.tap(find.text(ar.reminderDetailsDeleteAction));
      await tester.pumpAndSettle();

      // The confirmation sheet is up; the reminder must not be deleted yet.
      expect(find.text(ar.reminderDeleteSheetTitle), findsOneWidget);
      expect(remindersRepository.lastDeletedId, isNull);

      // The details screen's own delete button and the sheet's confirm
      // button happen to share the exact same Arabic label — the sheet's is
      // the one on top of the widget tree.
      await tester.tap(find.text(ar.reminderDeleteSheetConfirm).last);
      await tester.pumpAndSettle();

      expect(remindersRepository.lastDeletedId, 'r1');
      expect(closed, isTrue);
    });

    testWidgets('says so when the reminder is gone', (tester) async {
      remindersRepository.emitReminder('missing', null);
      cubit.start('missing');

      await pumpScreen(tester);

      expect(find.text(ar.reminderDetailsNotFoundTitle), findsOneWidget);
    });

    testWidgets('says so when the read fails', (tester) async {
      remindersRepository.emitReminderFailure('r1');
      cubit.start('r1');

      await pumpScreen(tester);

      expect(find.text(ar.reminderDetailsErrorTitle), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      remindersRepository.emitReminder('r1', fakeReminder());
      cubit.start('r1');

      await pumpScreen(tester, locale: AppLocalizations.english);

      expect(find.text(en.reminderDetailsTitle), findsOneWidget);
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      remindersRepository.emitReminder(
        'r1',
        fakeReminder(
          title: 'فاتورة الكهرباء لشهر أغسطس لشقة الدور الخامس والعشرين',
          documentId: 'doc-1',
        ),
      );
      cubit.start('r1');
      documentsRepository.emitDocument(
        savedDocumentWith(title: 'فاتورة كهرباء'),
      );

      await pumpScreen(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });
  });
}
