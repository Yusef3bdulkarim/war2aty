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
import 'package:war2aty/features/reminders/presentation/models/manual_reminder_seed.dart';
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
    ReminderFormCubit build({ManualReminderSeed? seed}) =>
        ReminderFormCubit.manual(
          createFromDocumentDate: createFromDocumentDate,
          createManual: createManual,
          getNotificationPermission: getNotificationPermission,
          requestNotificationPermission: requestNotificationPermission,
          seed: seed,
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

    // Found while building F29's seeded form, and fixed there — but it was
    // always reachable by hand: pick a date and time, then change the date.
    // A preset alert's row is labelled from its offset alone, so one left
    // behind showed «قبل الموعد بيوم» over an instant relative to a date the
    // user had already moved away from, and fired on the wrong day.
    group('a preset alert follows the event it is relative to', () {
      test('changing the date moves it', () {
        final cubit = build();
        addTearDown(cubit.close);
        cubit
          ..setEventDate(DateTime(2026, 9))
          ..setEventMinuteOfDay(9 * 60);

        cubit.setEventDate(DateTime(2026, 11, 20));

        final state = cubit.state as ReminderFormEditing;
        expect(state.alerts.single.offset, AlertTimeOffset.atEventTime);
        expect(state.alerts.single.time, state.eventInstant);
      });

      test('changing the time moves it', () {
        final cubit = build();
        addTearDown(cubit.close);
        cubit
          ..setEventDate(DateTime(2026, 9))
          ..setEventMinuteOfDay(9 * 60);

        cubit.setEventMinuteOfDay(20 * 60);

        final state = cubit.state as ReminderFormEditing;
        expect(state.alerts.single.time, state.eventInstant);
      });

      test('keeps each alert\'s own distance from the event', () {
        final cubit = build();
        addTearDown(cubit.close);
        cubit
          ..setEventDate(DateTime(2026, 9))
          ..setEventMinuteOfDay(9 * 60);
        // On top of the seeded "at event time" one.
        final instant = (cubit.state as ReminderFormEditing).eventInstant!;
        cubit.addAlert(
          ReminderAlertDraft(
            time: AlertTimeOffset.oneDayBefore.applyTo(instant),
            offset: AlertTimeOffset.oneDayBefore,
          ),
        );

        cubit.setEventDate(DateTime(2026, 11, 20));

        final state = cubit.state as ReminderFormEditing;
        final moved = state.eventInstant!;
        expect(state.alerts, [
          ReminderAlertDraft(time: moved, offset: AlertTimeOffset.atEventTime),
          ReminderAlertDraft(
            time: AlertTimeOffset.oneDayBefore.applyTo(moved),
            offset: AlertTimeOffset.oneDayBefore,
          ),
        ]);
      });

      test('a hand-picked instant is left exactly where the user put it', () {
        // No offset means the user named that moment outright — it was never
        // a function of the event, so the event moving must not drag it.
        final cubit = build();
        addTearDown(cubit.close);
        cubit
          ..setEventDate(DateTime(2026, 9))
          ..setEventMinuteOfDay(9 * 60);
        final custom = ReminderAlertDraft(time: DateTime.utc(2026, 8, 30, 7));
        cubit.addAlert(custom);

        cubit.setEventDate(DateTime(2026, 11, 20));

        expect((cubit.state as ReminderFormEditing).alerts, contains(custom));
      });

      test('what it saves is the moved time, not the original', () async {
        // The whole point: the repository must receive the alert the form
        // was showing, not the one it started with.
        final cubit = build();
        addTearDown(cubit.close);
        cubit
          ..setTitle('تذكير')
          ..setEventDate(DateTime(2026, 9))
          ..setEventMinuteOfDay(9 * 60)
          ..setEventDate(DateTime(2026, 11, 20));

        final moved = (cubit.state as ReminderFormEditing).eventInstant;
        await cubit.save();

        expect(repository.lastCreatedAlertTimes, [moved]);
      });
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

    // F29: the empty reminders list's quick rows open this same form with a
    // ready date in it.
    group('seeded from a quick date', () {
      final seed = ManualReminderSeed(
        eventDate: DateTime(2026, 10, 13),
        eventMinuteOfDay: 9 * 60,
      );

      test('opens holding the seeded date and time, and no title', () {
        final cubit = build(seed: seed);
        addTearDown(cubit.close);

        final state = cubit.state as ReminderFormEditing;
        expect(state.eventDate, DateTime(2026, 10, 13));
        expect(state.eventMinuteOfDay, 9 * 60);
        expect(state.isManual, isTrue);
        // Guessing a title would either be wrong or let an untitled reminder
        // through — the user still says what the reminder is about.
        expect(state.title, isEmpty);
      });

      test('opens with the same default alert a hand-filled form gets', () {
        final cubit = build(seed: seed);
        addTearDown(cubit.close);

        final state = cubit.state as ReminderFormEditing;
        expect(state.alerts, hasLength(1));
        expect(state.alerts.single.offset, AlertTimeOffset.atEventTime);
        expect(state.alerts.single.time, state.eventInstant);
      });

      test('is one typed title away from saveable', () {
        // The honest claim about concept D: a step fewer, not a tap.
        final cubit = build(seed: seed);
        addTearDown(cubit.close);

        expect((cubit.state as ReminderFormEditing).canSave, isFalse);

        cubit.setTitle('امتحان');
        expect((cubit.state as ReminderFormEditing).canSave, isTrue);
      });

      test('is indistinguishable from the same form filled in by hand', () {
        // The property that keeps the two paths from drifting: a seed is a
        // shortcut through the form, not a second kind of form.
        final seeded = build(seed: seed);
        addTearDown(seeded.close);
        seeded.setTitle('امتحان');

        final byHand = build();
        addTearDown(byHand.close);
        byHand
          ..setTitle('امتحان')
          ..setEventDate(DateTime(2026, 10, 13))
          ..setEventMinuteOfDay(9 * 60);

        final a = seeded.state as ReminderFormEditing;
        final b = byHand.state as ReminderFormEditing;
        expect(a.eventDate, b.eventDate);
        expect(a.eventMinuteOfDay, b.eventMinuteOfDay);
        expect(a.eventInstant, b.eventInstant);
        expect(a.alerts, b.alerts);
        expect(a.canSave, b.canSave);
      });

      test('the seeded date is still the user\'s to change', () {
        // A seed is a starting point, not a decision.
        final cubit = build(seed: seed);
        addTearDown(cubit.close);

        cubit.setEventDate(DateTime(2026, 12));
        cubit.setEventMinuteOfDay(18 * 60);

        final state = cubit.state as ReminderFormEditing;
        expect(state.eventDate, DateTime(2026, 12));
        expect(state.eventMinuteOfDay, 18 * 60);
      });

      test('moving the date takes the seeded alert with it', () {
        // Without this, the form would show «في وقت الحدث» over an alert
        // still pointing at the seeded day — and fire on the wrong one.
        final cubit = build(seed: seed);
        addTearDown(cubit.close);

        cubit.setEventDate(DateTime(2026, 12));

        final state = cubit.state as ReminderFormEditing;
        expect(state.alerts.single.offset, AlertTimeOffset.atEventTime);
        expect(state.alerts.single.time, state.eventInstant);
      });

      test('saves the seeded date through to the repository', () async {
        final cubit = build(seed: seed);
        addTearDown(cubit.close);
        cubit.setTitle('امتحان');

        await cubit.save();

        expect(repository.lastCreatedEventDate, DateTime(2026, 10, 13));
        expect(repository.lastCreatedEventMinuteOfDay, 9 * 60);
        expect(repository.lastCreatedIsManual, isTrue);
        expect(repository.lastCreatedAlertTimes, hasLength(1));
      });

      test('no seed still opens the empty form it always did', () {
        // The header's «إضافة تذكير» passes nothing, and must be untouched
        // by all of the above.
        final cubit = build();
        addTearDown(cubit.close);

        final state = cubit.state as ReminderFormEditing;
        expect(state.eventDate, isNull);
        expect(state.eventMinuteOfDay, isNull);
        expect(state.alerts, isEmpty);
      });
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
