import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/request_notification_permission.dart';
import 'package:war2aty/core/reminders/alert_time_offset.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_state.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_alert_draft.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_from_document_args.dart';

import '../../support/fakes.dart';

void main() {
  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;
  late CreateReminderFromDocumentDate createFromDocumentDate;
  late CreateManualReminder createManual;
  late FakeNotificationPermissionRepository notificationPermissionRepository;
  late GetNotificationPermission getNotificationPermission;
  late RequestNotificationPermission requestNotificationPermission;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    createFromDocumentDate = CreateReminderFromDocumentDate(
      repository,
      scheduler,
    );
    createManual = CreateManualReminder(repository, scheduler);
    notificationPermissionRepository = FakeNotificationPermissionRepository();
    getNotificationPermission = GetNotificationPermission(
      notificationPermissionRepository,
    );
    requestNotificationPermission = RequestNotificationPermission(
      notificationPermissionRepository,
    );
  });

  group('fromDocument', () {
    ReminderFormCubit build({
      String? documentId,
      String? documentTitle,
      int? eventMinuteOfDay,
    }) => ReminderFormCubit.fromDocument(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
      args: ReminderFromDocumentArgs(
        documentId: documentId,
        documentTitle: documentTitle,
        title: 'دفع فاتورة الكهرباء',
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: eventMinuteOfDay,
      ),
    );

    test('starts with the paper\'s title, date and time prefilled', () {
      final cubit = build(eventMinuteOfDay: 600);
      addTearDown(cubit.close);

      final state = cubit.state as ReminderFormEditing;
      expect(state.title, 'دفع فاتورة الكهرباء');
      expect(state.eventDate, DateTime(2026, 8, 25));
      expect(state.eventMinuteOfDay, 600);
      expect(state.isManual, isFalse);
    });

    test('defaults to a day-before alert when the paper gave a time', () {
      final cubit = build(eventMinuteOfDay: 600);
      addTearDown(cubit.close);

      final state = cubit.state as ReminderFormEditing;
      expect(state.alerts, hasLength(1));
      expect(state.alerts.single.offset, AlertTimeOffset.oneDayBefore);
    });

    test('starts with no alert when the paper gave no time (F09-T06)', () {
      final cubit = build();
      addTearDown(cubit.close);

      expect((cubit.state as ReminderFormEditing).alerts, isEmpty);
    });

    test('canSave does not require an event time', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.addAlert(ReminderAlertDraft(time: DateTime(2026, 8, 20)));

      expect((cubit.state as ReminderFormEditing).canSave, isTrue);
    });

    test('canSave is false with no alerts yet', () {
      final cubit = build();
      addTearDown(cubit.close);

      expect((cubit.state as ReminderFormEditing).canSave, isFalse);
    });

    test(
      'save calls the from-document use case with the document id',
      () async {
        final cubit = build(
          documentId: 'doc-1',
          documentTitle: 'فاتورة كهرباء',
          eventMinuteOfDay: 600,
        );
        addTearDown(cubit.close);

        await cubit.save();

        expect(repository.lastCreatedDocumentId, 'doc-1');
        expect(repository.lastCreatedIsManual, isFalse);
        expect(cubit.state, isA<ReminderFormSaved>());
      },
    );

    test('save with no document links nothing', () async {
      final cubit = build(eventMinuteOfDay: 600);
      addTearDown(cubit.close);

      await cubit.save();

      expect(repository.lastCreatedDocumentId, isNull);
    });

    test('save reports the failure and keeps the form editable', () async {
      repository.createOutcome = const Err(LocalDatabaseFailure());
      final cubit = build(eventMinuteOfDay: 600);
      addTearDown(cubit.close);

      await cubit.save();

      final state = cubit.state as ReminderFormSaveFailed;
      expect(state.failure, const LocalDatabaseFailure());
      expect(state.editing.isSaving, isFalse);
    });
  });

  group('manual', () {
    ReminderFormCubit build() => ReminderFormCubit.manual(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
    );

    test('starts empty', () {
      final cubit = build();
      addTearDown(cubit.close);

      final state = cubit.state as ReminderFormEditing;
      expect(state.title, isEmpty);
      expect(state.eventDate, isNull);
      expect(state.alerts, isEmpty);
      expect(state.isManual, isTrue);
    });

    test('canSave requires a title, a date and a time', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.setTitle('تذكير جديد');
      cubit.setEventDate(DateTime(2026, 9));

      expect((cubit.state as ReminderFormEditing).canSave, isFalse);

      cubit.setEventMinuteOfDay(9 * 60);
      expect((cubit.state as ReminderFormEditing).canSave, isTrue);
    });

    test(
      'seeds a default "at event time" alert once date and time are both set',
      () {
        final cubit = build();
        addTearDown(cubit.close);
        cubit.setTitle('تذكير جديد');
        cubit.setEventDate(DateTime(2026, 9));
        cubit.setEventMinuteOfDay(9 * 60);

        final state = cubit.state as ReminderFormEditing;
        expect(state.alerts, hasLength(1));
        expect(state.alerts.single.offset, AlertTimeOffset.atEventTime);
        expect(state.alerts.single.time, state.eventInstant);
      },
    );

    test('does not overwrite an alert the user already added', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.setEventDate(DateTime(2026, 9));
      final custom = ReminderAlertDraft(time: DateTime(2026, 8, 30));
      cubit.addAlert(custom);

      cubit.setEventMinuteOfDay(9 * 60);

      expect((cubit.state as ReminderFormEditing).alerts, [custom]);
    });

    test('addAlert respects the 3-alert cap by simply trusting its caller', () {
      final cubit = build();
      addTearDown(cubit.close);
      for (var i = 0; i < 3; i++) {
        cubit.addAlert(ReminderAlertDraft(time: DateTime(2026, 8, 20 + i)));
      }

      expect((cubit.state as ReminderFormEditing).alerts, hasLength(3));
    });

    test('removeAlertAt drops just that one', () {
      final cubit = build();
      addTearDown(cubit.close);
      final first = ReminderAlertDraft(time: DateTime(2026, 8, 20));
      final second = ReminderAlertDraft(time: DateTime(2026, 8, 21));
      cubit
        ..addAlert(first)
        ..addAlert(second)
        ..removeAlertAt(0);

      expect((cubit.state as ReminderFormEditing).alerts, [second]);
    });

    test('save calls the manual use case with isManual true', () async {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.setTitle('تذكير جديد');
      cubit.setEventDate(DateTime(2026, 9));
      cubit.setEventMinuteOfDay(9 * 60);

      await cubit.save();

      expect(repository.lastCreatedIsManual, isTrue);
      expect(repository.lastCreatedTitle, 'تذكير جديد');
    });

    test('blank whitespace title does not satisfy canSave', () {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.setTitle('   ');
      cubit.setEventDate(DateTime(2026, 9));
      cubit.setEventMinuteOfDay(9 * 60);

      expect((cubit.state as ReminderFormEditing).canSave, isFalse);
    });
  });

  test('a note left blank is saved as null, not an empty string', () async {
    final cubit = ReminderFormCubit.manual(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
    );
    addTearDown(cubit.close);
    cubit
      ..setTitle('ت')
      ..setEventDate(DateTime(2026, 9))
      ..setEventMinuteOfDay(600)
      ..setDescription('   ');

    await cubit.save();

    expect(repository.lastCreatedDescription, isNull);
  });

  test('the saved reminder carries through to ReminderFormSaved', () async {
    repository.createOutcome = Ok(fakeReminder(id: 'r9'));
    final cubit = ReminderFormCubit.manual(
      createFromDocumentDate: createFromDocumentDate,
      createManual: createManual,
      getNotificationPermission: getNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
    );
    addTearDown(cubit.close);
    cubit
      ..setTitle('ت')
      ..setEventDate(DateTime(2026, 9))
      ..setEventMinuteOfDay(600);

    await cubit.save();

    final state = cubit.state as ReminderFormSaved;
    expect(state.reminder, isA<Reminder>());
    expect(state.reminder.id, 'r9');
  });
}
