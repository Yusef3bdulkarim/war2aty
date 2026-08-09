// `isNull`/`isNotNull` are drift SQL expressions too; the matchers win here.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/reminders_dao.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/reminders/reminder_alert_status.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late RemindersDao dao;

  setUp(() {
    db = memoryDatabase();
    dao = db.remindersDao;
  });
  tearDown(() => db.close());

  group('saveReminder', () {
    test('round-trips a manual reminder with no alerts', () async {
      await dao.saveReminder(ReminderWrite(reminder: _reminder('r1')));

      final bundle = await dao.reminderById('r1');

      expect(bundle, isNotNull);
      expect(bundle!.reminder.title, 'دفع فاتورة الكهرباء');
      expect(bundle.reminder.status, ReminderStatus.pending);
      expect(bundle.reminder.documentId, isNull);
      expect(bundle.alerts, isEmpty);
    });

    test('writes every alert for the reminder', () async {
      await dao.saveReminder(
        ReminderWrite(
          reminder: _reminder('r1'),
          alerts: [
            _alert('a1', 'r1', DateTime(2026, 8, 24, 8)),
            _alert('a2', 'r1', DateTime(2026, 8, 23, 8)),
          ],
        ),
      );

      final bundle = await dao.reminderById('r1');

      // Earliest first, regardless of insert order.
      expect(bundle!.alerts.map((a) => a.id), ['a2', 'a1']);
    });

    test('re-saving the same id replaces its alerts entirely', () async {
      await dao.saveReminder(
        ReminderWrite(
          reminder: _reminder('r1'),
          alerts: [_alert('a1', 'r1', DateTime(2026, 8, 24, 8))],
        ),
      );

      await dao.saveReminder(
        ReminderWrite(
          reminder: _reminder('r1'),
          alerts: [_alert('a2', 'r1', DateTime(2026, 8, 25, 8))],
        ),
      );

      final bundle = await dao.reminderById('r1');
      expect(bundle!.alerts.map((a) => a.id), ['a2']);
    });
  });

  group('replaceAlerts', () {
    test('swaps the alert set without touching the reminder row', () async {
      await dao.saveReminder(
        ReminderWrite(
          reminder: _reminder('r1'),
          alerts: [_alert('a1', 'r1', DateTime(2026, 8, 24, 8))],
        ),
      );

      await dao.replaceAlerts('r1', [
        ReminderAlertsCompanion.insert(
          id: 'a2',
          reminderId: 'r1',
          scheduledAt: DateTime(2026, 8, 25, 8),
          notificationId: 2,
          status: ReminderAlertStatus.scheduled,
          createdAt: DateTime(2026),
        ),
      ]);

      final bundle = await dao.reminderById('r1');
      expect(bundle!.reminder.title, 'دفع فاتورة الكهرباء');
      expect(bundle.alerts.single.id, 'a2');
    });

    test('an empty replacement clears every alert', () async {
      await dao.saveReminder(
        ReminderWrite(
          reminder: _reminder('r1'),
          alerts: [_alert('a1', 'r1', DateTime(2026, 8, 24, 8))],
        ),
      );

      await dao.replaceAlerts('r1', []);

      final bundle = await dao.reminderById('r1');
      expect(bundle!.alerts, isEmpty);
    });
  });

  test('reminderById answers null for a missing reminder', () async {
    expect(await dao.reminderById('missing'), isNull);
  });

  test('watchReminders emits again after a write', () async {
    final emissions = <int>[];
    final sub = dao.watchReminders().listen((b) => emissions.add(b.length));
    await pumpEventQueue();

    await dao.saveReminder(ReminderWrite(reminder: _reminder('r1')));
    await pumpEventQueue();

    await sub.cancel();
    expect(emissions, [0, 1]);
  });

  test('pendingBundles excludes completed reminders', () async {
    await dao.saveReminder(ReminderWrite(reminder: _reminder('r1')));
    await dao.saveReminder(ReminderWrite(reminder: _reminder('r2')));
    await dao.completeReminder('r2', completedAt: DateTime(2026));

    final pending = await dao.pendingBundles();
    expect(pending.map((b) => b.reminder.id), ['r1']);
  });

  test(
    'bundlesForDocument narrows to reminders linked to that document',
    () async {
      await db.into(db.documents).insert(_documentRow('doc-1'));
      await dao.saveReminder(
        ReminderWrite(reminder: _reminder('r1', documentId: 'doc-1')),
      );
      await dao.saveReminder(ReminderWrite(reminder: _reminder('r2')));

      final linked = await dao.bundlesForDocument('doc-1');
      expect(linked.map((b) => b.reminder.id), ['r1']);
    },
  );

  group('updateReminder', () {
    test('changes only the given fields', () async {
      await dao.saveReminder(ReminderWrite(reminder: _reminder('r1')));

      await dao.updateReminder(
        'r1',
        title: 'عنوان جديد',
        updatedAt: DateTime(2026, 2, 2),
      );

      final bundle = await dao.reminderById('r1');
      expect(bundle!.reminder.title, 'عنوان جديد');
      expect(bundle.reminder.updatedAt, DateTime(2026, 2, 2));
    });

    test('an absent description leaves the stored one untouched', () async {
      await dao.saveReminder(
        ReminderWrite(reminder: _reminder('r1', description: 'ملاحظة')),
      );

      await dao.updateReminder('r1', title: 'عنوان', updatedAt: DateTime(2026));

      final bundle = await dao.reminderById('r1');
      expect(bundle!.reminder.description, 'ملاحظة');
    });

    test('an explicit null description clears it', () async {
      await dao.saveReminder(
        ReminderWrite(reminder: _reminder('r1', description: 'ملاحظة')),
      );

      await dao.updateReminder(
        'r1',
        description: const Value(null),
        updatedAt: DateTime(2026),
      );

      final bundle = await dao.reminderById('r1');
      expect(bundle!.reminder.description, isNull);
    });
  });

  test('completeReminder marks status and stamps completedAt', () async {
    await dao.saveReminder(ReminderWrite(reminder: _reminder('r1')));

    await dao.completeReminder('r1', completedAt: DateTime(2026, 3, 3));

    final bundle = await dao.reminderById('r1');
    expect(bundle!.reminder.status, ReminderStatus.completed);
    expect(bundle.reminder.completedAt, DateTime(2026, 3, 3));
  });

  test('deleteReminder removes its alerts through the cascade', () async {
    await dao.saveReminder(
      ReminderWrite(
        reminder: _reminder('r1'),
        alerts: [_alert('a1', 'r1', DateTime(2026, 8, 24, 8))],
      ),
    );

    await dao.deleteReminder('r1');

    expect(await dao.reminderById('r1'), isNull);
  });

  test('deleteAllReminders empties the table', () async {
    await dao.saveReminder(ReminderWrite(reminder: _reminder('r1')));
    await dao.saveReminder(ReminderWrite(reminder: _reminder('r2')));

    await dao.deleteAllReminders();

    expect(await dao.reminderById('r1'), isNull);
    expect(await dao.reminderById('r2'), isNull);
  });

  test(
    'setAlertStatus updates one alert without touching the others',
    () async {
      await dao.saveReminder(
        ReminderWrite(
          reminder: _reminder('r1'),
          alerts: [
            _alert('a1', 'r1', DateTime(2026, 8, 24, 8)),
            _alert('a2', 'r1', DateTime(2026, 8, 25, 8)),
          ],
        ),
      );

      await dao.setAlertStatus('a1', ReminderAlertStatus.delivered);

      final bundle = await dao.reminderById('r1');
      final byId = {for (final a in bundle!.alerts) a.id: a.status};
      expect(byId['a1'], ReminderAlertStatus.delivered);
      expect(byId['a2'], ReminderAlertStatus.scheduled);
    },
  );

  test('deleting the linked document cascades onto the reminder', () async {
    await db.into(db.documents).insert(_documentRow('doc-1'));
    await dao.saveReminder(
      ReminderWrite(reminder: _reminder('r1', documentId: 'doc-1')),
    );

    await (db.delete(db.documents)..where((t) => t.id.equals('doc-1'))).go();

    expect(await dao.reminderById('r1'), isNull);
  });
}

RemindersCompanion _reminder(
  String id, {
  String? documentId,
  String? description,
}) => RemindersCompanion.insert(
  id: id,
  documentId: documentId == null ? const Value.absent() : Value(documentId),
  title: 'دفع فاتورة الكهرباء',
  description: description == null ? const Value.absent() : Value(description),
  eventDate: DateTime(2026, 8, 25),
  eventMinuteOfDay: const Value(600),
  status: ReminderStatus.pending,
  isManual: documentId == null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ReminderAlertsCompanion _alert(String id, String reminderId, DateTime at) =>
    ReminderAlertsCompanion.insert(
      id: id,
      reminderId: reminderId,
      scheduledAt: at,
      notificationId: id.hashCode & 0x7fffffff,
      status: ReminderAlertStatus.scheduled,
      createdAt: DateTime(2026),
    );

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
