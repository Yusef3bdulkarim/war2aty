import '../database/app_database.dart';
import '../database/daos/reminders_dao.dart';
import 'reminder.dart';
import 'reminder_alert.dart';

/// Turns a stored [ReminderBundle] back into the entity the reminders
/// feature works with.
///
/// The reverse of `reminderWriteOf` (`reminder_write_mapper.dart`). Unlike
/// `document_read_mapper`, there is no by-name enum parsing to do here: both
/// [Reminders.status] and [ReminderAlerts.status] are `textEnum` columns, so
/// drift already hands back a typed [ReminderStatus]/[ReminderAlertStatus] on
/// the row — a value written by a since-changed enum simply fails to open the
/// database rather than silently degrading, the same trade-off `Documents`
/// makes for `category` and `storageMode`.
Reminder reminderOf(ReminderBundle bundle) {
  final row = bundle.reminder;

  return Reminder(
    id: row.id,
    documentId: row.documentId,
    title: row.title,
    description: row.description,
    eventDate: row.eventDate,
    eventMinuteOfDay: row.eventMinuteOfDay,
    status: row.status,
    isManual: row.isManual,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    completedAt: row.completedAt,
    alerts: [for (final alert in bundle.alerts) reminderAlertOf(alert)],
  );
}

ReminderAlert reminderAlertOf(ReminderAlertRow row) => ReminderAlert(
  id: row.id,
  reminderId: row.reminderId,
  scheduledAt: row.scheduledAt,
  status: row.status,
);
