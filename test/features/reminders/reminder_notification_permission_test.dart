import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/request_notification_permission.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_state.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_from_document_args.dart';

import '../../support/fakes.dart';

// F09-T09: requesting notifications before the first reminder is saved.
void main() {
  late FakeRemindersRepository remindersRepository;
  late CreateReminderFromDocumentDate createFromDocumentDate;
  late CreateManualReminder createManual;
  late FakeNotificationPermissionRepository notificationPermissionRepository;
  late GetNotificationPermission getNotificationPermission;
  late RequestNotificationPermission requestNotificationPermission;

  setUp(() {
    remindersRepository = FakeRemindersRepository();
    final scheduler = FakeReminderScheduler();
    createFromDocumentDate = CreateReminderFromDocumentDate(
      remindersRepository,
      scheduler,
    );
    createManual = CreateManualReminder(remindersRepository, scheduler);
    notificationPermissionRepository = FakeNotificationPermissionRepository();
    getNotificationPermission = GetNotificationPermission(
      notificationPermissionRepository,
    );
    requestNotificationPermission = RequestNotificationPermission(
      notificationPermissionRepository,
    );
  });

  ReminderFormCubit buildCubit() => ReminderFormCubit.fromDocument(
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

  test('already granted: save writes straight through, no sheet', () async {
    notificationPermissionRepository.status = PermissionOutcome.granted;
    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.save();

    expect(cubit.state, isA<ReminderFormSaved>());
    expect(notificationPermissionRepository.requestCount, 0);
  });

  test(
    'not yet granted: save stops for the permission sheet instead',
    () async {
      notificationPermissionRepository.status = PermissionOutcome.denied;
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.save();

      expect(cubit.state, isA<ReminderFormNeedsNotificationPermission>());
      expect(remindersRepository.lastCreatedTitle, isNull);
    },
  );

  test(
    'allowNotificationsAndSave requests permission, then saves regardless',
    () async {
      notificationPermissionRepository
        ..status = PermissionOutcome.denied
        ..afterRequest = PermissionOutcome.denied;
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.save();

      await cubit.allowNotificationsAndSave();

      expect(notificationPermissionRepository.requestCount, 1);
      expect(cubit.state, isA<ReminderFormSaved>());
    },
  );

  test('saveWithoutNotifications saves without ever prompting', () async {
    notificationPermissionRepository.status = PermissionOutcome.denied;
    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.save();

    await cubit.saveWithoutNotifications();

    expect(notificationPermissionRepository.requestCount, 0);
    expect(cubit.state, isA<ReminderFormSaved>());
  });

  test('cancelling the prompt goes back to editing, nothing written', () async {
    notificationPermissionRepository.status = PermissionOutcome.denied;
    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.save();

    cubit.cancelNotificationPermissionPrompt();

    expect(cubit.state, isA<ReminderFormEditing>());
    expect(remindersRepository.lastCreatedTitle, isNull);
  });

  test('a second save after granting mid-session does not re-prompt', () async {
    notificationPermissionRepository.status = PermissionOutcome.denied;
    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.save();
    await cubit.allowNotificationsAndSave();
    notificationPermissionRepository.status = PermissionOutcome.granted;

    // A brand-new form (e.g. the next reminder) sees the now-granted status
    // straight away — nothing about "having asked before" needs tracking.
    final second = buildCubit();
    addTearDown(second.close);
    await second.save();

    expect(second.state, isA<ReminderFormSaved>());
  });
}
