import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/reminders_dao.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/drift_reminders_repository.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/reminder_alert_status.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late RemindersDao dao;
  late DriftRemindersRepository repository;
  var nextId = 0;

  setUp(() {
    db = memoryDatabase();
    dao = db.remindersDao;
    nextId = 0;
    repository = DriftRemindersRepository(
      dao,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime(2026, 8),
    );
  });
  tearDown(() => db.close());

  Future<Reminder> create({
    String? documentId,
    String title = 'دفع فاتورة الكهرباء',
    String? description,
    DateTime? eventDate,
    int? eventMinuteOfDay,
    bool isManual = true,
    List<DateTime> alertTimes = const [],
  }) async {
    final outcome = await repository.createReminder(
      documentId: documentId,
      title: title,
      description: description,
      eventDate: eventDate ?? DateTime(2026, 8, 25),
      eventMinuteOfDay: eventMinuteOfDay,
      isManual: isManual,
      alertTimes: alertTimes.isEmpty ? [DateTime(2026, 8, 24, 10)] : alertTimes,
    );
    return (outcome as Ok<Reminder, AppFailure>).value;
  }

  group('createReminder', () {
    test('writes the reminder and every alert it was given', () async {
      final reminder = await create(
        alertTimes: [DateTime(2026, 8, 24, 10), DateTime(2026, 8, 23, 10)],
      );

      expect(reminder.title, 'دفع فاتورة الكهرباء');
      expect(reminder.status, ReminderStatus.pending);
      expect(reminder.alerts.map((a) => a.scheduledAt), [
        DateTime(2026, 8, 23, 10),
        DateTime(2026, 8, 24, 10),
      ]);
    });

    test('every alert starts scheduled', () async {
      final reminder = await create();
      expect(reminder.alerts.single.status, ReminderAlertStatus.scheduled);
    });

    test('stamps createdAt/updatedAt with the injected clock', () async {
      final reminder = await create();
      expect(reminder.createdAt, DateTime(2026, 8));
      expect(reminder.updatedAt, DateTime(2026, 8));
    });
  });

  group('updateReminder', () {
    test('changes the title without touching the alerts', () async {
      final reminder = await create(title: 'قديم');

      await repository.updateReminder(reminder.id, title: 'جديد');

      final bundle = await dao.reminderById(reminder.id);
      expect(bundle!.reminder.title, 'جديد');
      expect(bundle.alerts, hasLength(1));
    });

    test('replaces the alert set when alertTimes is given', () async {
      final reminder = await create();

      await repository.updateReminder(
        reminder.id,
        alertTimes: [DateTime(2026, 8, 20, 9), DateTime(2026, 8, 21, 9)],
      );

      final bundle = await dao.reminderById(reminder.id);
      expect(bundle!.alerts.map((a) => a.scheduledAt), [
        DateTime(2026, 8, 20, 9),
        DateTime(2026, 8, 21, 9),
      ]);
    });

    test('clearDescription blanks the note explicitly', () async {
      final reminder = await create(description: 'ملاحظة');

      await repository.updateReminder(reminder.id, clearDescription: true);

      final bundle = await dao.reminderById(reminder.id);
      expect(bundle!.reminder.description, isNull);
    });
  });

  test('completeReminder marks it done', () async {
    final reminder = await create();

    await repository.completeReminder(reminder.id);

    final bundle = await dao.reminderById(reminder.id);
    expect(bundle!.reminder.status, ReminderStatus.completed);
    expect(bundle.reminder.completedAt, DateTime(2026, 8));
  });

  test('snoozeReminder replaces every alert with a single new one', () async {
    final reminder = await create(
      alertTimes: [DateTime(2026, 8, 20, 9), DateTime(2026, 8, 21, 9)],
    );

    await repository.snoozeReminder(reminder.id, DateTime(2026, 8, 26, 9));

    final bundle = await dao.reminderById(reminder.id);
    expect(bundle!.alerts, hasLength(1));
    expect(bundle.alerts.single.scheduledAt, DateTime(2026, 8, 26, 9));
  });

  test('deleteReminder removes it', () async {
    final reminder = await create();

    await repository.deleteReminder(reminder.id);

    expect(await dao.reminderById(reminder.id), isNull);
  });

  test('deleteAllReminders empties the table', () async {
    await create();

    await repository.deleteAllReminders();

    final all = await repository.watchReminders().first;
    expect((all as Ok<List<Reminder>, AppFailure>).value, isEmpty);
  });

  test('pendingReminders excludes completed reminders', () async {
    final r1 = await create(title: 'واحد');
    final r2 = await create(title: 'اتنين');
    await repository.completeReminder(r2.id);

    final pending = await repository.pendingReminders();
    expect((pending as Ok<List<Reminder>, AppFailure>).value.map((r) => r.id), [
      r1.id,
    ]);
  });

  test('remindersForDocument narrows to the linked document', () async {
    await db.into(db.documents).insert(_documentRow('doc-1'));
    final linkedReminder = await create(
      documentId: 'doc-1',
      title: 'من ورقة',
      isManual: false,
    );
    await create(title: 'يدوي');

    final linked = await repository.remindersForDocument('doc-1');
    expect((linked as Ok<List<Reminder>, AppFailure>).value.map((r) => r.id), [
      linkedReminder.id,
    ]);
  });

  test('setAlertStatus updates just that alert', () async {
    final reminder = await create();

    await repository.setAlertStatus(
      reminder.alerts.single.id,
      ReminderAlertStatus.delivered,
    );

    final bundle = await dao.reminderById(reminder.id);
    expect(bundle!.alerts.single.status, ReminderAlertStatus.delivered);
  });

  test('watchReminder emits null once the reminder is deleted', () async {
    final reminder = await create();

    final emissions = <String?>[];
    final sub = repository.watchReminder(reminder.id).listen((r) {
      emissions.add((r as Ok<Reminder?, AppFailure>).value?.id);
    });
    await pumpEventQueue();

    await repository.deleteReminder(reminder.id);
    await pumpEventQueue();

    await sub.cancel();
    expect(emissions, [reminder.id, null]);
  });
}

DocumentsCompanion _documentRow(String id) => DocumentsCompanion.insert(
  id: id,
  title: 'فاتورة كهرباء',
  category: DocumentCategory.invoice,
  kind: 'invoice',
  status: 'complete',
  kindConfidence: 'high',
  summaryShort: 'ملخص',
  summaryDetailed: 'شرح',
  extractedText: 'نص',
  storageMode: DocumentStorageMode.resultOnly,
  sessionId: 's1',
  savedAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
