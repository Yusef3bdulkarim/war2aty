import 'package:drift/drift.dart';

import '../../reminders/reminder_alert_status.dart';
import '../../reminders/reminder_status.dart';
import '../app_database.dart';
import '../tables/reminder_tables.dart';

part 'reminders_dao.g.dart';

/// One reminder with every alert that belongs to it.
///
/// Same shape as `DocumentBundle`: a raw storage aggregate the feature's
/// mapper turns into a [Reminder] entity, kept together so a caller reads a
/// reminder and its alerts in one transaction instead of two queries.
final class ReminderBundle {
  const ReminderBundle({required this.reminder, this.alerts = const []});

  final ReminderRow reminder;

  /// Earliest alert first — the order the list row and the form both read
  /// alerts in.
  final List<ReminderAlertRow> alerts;
}

/// Everything written when a reminder is created or edited.
final class ReminderWrite {
  const ReminderWrite({required this.reminder, this.alerts = const []});

  final RemindersCompanion reminder;
  final List<ReminderAlertsCompanion> alerts;
}

/// Local storage for reminders (F09).
///
/// The only place that touches the reminder tables. Like `DocumentsDao`, it
/// hands out rows and streams of rows — no domain types, no [AppFailure], no
/// Arabic copy; the repository above it owns mapping and error translation.
@DriftAccessor(tables: [Reminders, ReminderAlerts])
class RemindersDao extends DatabaseAccessor<AppDatabase>
    with _$RemindersDaoMixin {
  RemindersDao(super.db);

  /// Writes a reminder and replaces its alert set, in one transaction.
  ///
  /// Re-saving the same id replaces its alerts entirely rather than diffing
  /// them — creation, editing the alert set (F09-T08) and snoozing (F09-T12)
  /// all reason about "the alerts this reminder has" as a whole, never about
  /// one alert in isolation.
  Future<void> saveReminder(ReminderWrite write) {
    return transaction(() async {
      final id = write.reminder.id.value;
      await into(reminders).insertOnConflictUpdate(write.reminder);
      await _replaceAlerts(id, write.alerts);
    });
  }

  /// Replaces [reminderId]'s alerts without touching the reminder row itself.
  Future<void> replaceAlerts(
    String reminderId,
    List<ReminderAlertsCompanion> alerts,
  ) {
    return transaction(() => _replaceAlerts(reminderId, alerts));
  }

  Future<void> _replaceAlerts(
    String reminderId,
    List<ReminderAlertsCompanion> alerts,
  ) async {
    await (delete(
      reminderAlerts,
    )..where((t) => t.reminderId.equals(reminderId))).go();
    if (alerts.isNotEmpty) {
      await batch((b) => b.insertAll(reminderAlerts, alerts));
    }
  }

  /// Watches every reminder with its alerts, oldest event first.
  ///
  /// Reminders are a short personal list — reading the whole table on every
  /// change is simpler than a paged query and, at this scale, no slower.
  Stream<List<ReminderBundle>> watchReminders() {
    final trigger = customSelect(
      'SELECT 1',
      readsFrom: {reminders, reminderAlerts},
    ).watch();
    return trigger.asyncMap((_) => _allBundles());
  }

  Future<List<ReminderBundle>> _allBundles() async {
    final rows = await (select(
      reminders,
    )..orderBy([(t) => OrderingTerm.asc(t.eventDate)])).get();
    final allAlerts = await select(reminderAlerts).get();

    return [
      for (final row in rows)
        ReminderBundle(
          reminder: row,
          alerts: _sorted(
            allAlerts.where((a) => a.reminderId == row.id).toList(),
          ),
        ),
    ];
  }

  /// Reads one reminder with its alerts, or `null` if it is not there.
  Future<ReminderBundle?> reminderById(String id) async {
    final row = await (select(
      reminders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return ReminderBundle(reminder: row, alerts: await _alertsOf(id));
  }

  /// Watches one reminder with its alerts. Emits `null` once it is gone.
  Stream<ReminderBundle?> watchReminderById(String id) {
    final trigger = customSelect(
      'SELECT 1',
      readsFrom: {reminders, reminderAlerts},
    ).watch();
    return trigger.asyncMap((_) => reminderById(id));
  }

  /// Every reminder still awaiting the user, for the OS scheduler to
  /// reconcile against (F09-T13) — a completed reminder has nothing left to
  /// schedule.
  Future<List<ReminderBundle>> pendingBundles() async {
    final rows = await (select(
      reminders,
    )..where((t) => t.status.equalsValue(ReminderStatus.pending))).get();
    final allAlerts = await select(reminderAlerts).get();

    return [
      for (final row in rows)
        ReminderBundle(
          reminder: row,
          alerts: _sorted(
            allAlerts.where((a) => a.reminderId == row.id).toList(),
          ),
        ),
    ];
  }

  /// Every reminder linked to [documentId] — read before the document is
  /// deleted, so the caller can cancel their OS-side alerts while the
  /// notification ids are still known.
  Future<List<ReminderBundle>> bundlesForDocument(String documentId) async {
    final rows = await (select(
      reminders,
    )..where((t) => t.documentId.equals(documentId))).get();

    return [
      for (final row in rows)
        ReminderBundle(reminder: row, alerts: await _alertsOf(row.id)),
    ];
  }

  /// Updates the fields a reminder's own form can change, leaving the rest —
  /// alerts go through [replaceAlerts]. Every field is optional; passing none
  /// only touches `updatedAt`.
  Future<void> updateReminder(
    String id, {
    String? title,
    Value<String?> description = const Value.absent(),
    required DateTime updatedAt,
  }) {
    return (update(reminders)..where((t) => t.id.equals(id))).write(
      RemindersCompanion(
        title: title == null ? const Value.absent() : Value(title),
        description: description,
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Marks a reminder done (F09-T12). Idempotent: completing an
  /// already-completed reminder just refreshes its timestamps.
  Future<void> completeReminder(String id, {required DateTime completedAt}) {
    return (update(reminders)..where((t) => t.id.equals(id))).write(
      RemindersCompanion(
        status: const Value(ReminderStatus.completed),
        completedAt: Value(completedAt),
        updatedAt: Value(completedAt),
      ),
    );
  }

  /// Deletes a reminder. Its alerts go with it through the cascade.
  Future<void> deleteReminder(String id) {
    return (delete(reminders)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes every reminder (settings' "حذف كل التذكيرات").
  Future<void> deleteAllReminders() => delete(reminders).go();

  /// Records what happened when the scheduler tried to (re)schedule one
  /// alert (F09-T10/T13).
  Future<void> setAlertStatus(String alertId, ReminderAlertStatus status) {
    return (update(reminderAlerts)..where((t) => t.id.equals(alertId))).write(
      ReminderAlertsCompanion(status: Value(status)),
    );
  }

  Future<List<ReminderAlertRow>> _alertsOf(String reminderId) {
    final query = select(reminderAlerts)
      ..where((t) => t.reminderId.equals(reminderId));
    return query.get().then(_sorted);
  }

  List<ReminderAlertRow> _sorted(List<ReminderAlertRow> alerts) =>
      alerts..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}
