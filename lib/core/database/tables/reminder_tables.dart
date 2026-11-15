import 'package:drift/drift.dart';

import '../../reminders/reminder_alert_status.dart';
import '../../reminders/reminder_status.dart';

/// A thing the user wants to be reminded about (F09).
///
/// One row per reminder. The times it fires live in [ReminderAlerts], a
/// separate table, because a reminder can carry up to three of them
/// (F09-T08) — the *event* below is singular, the *alerts* about it are not.
///
/// Every reminder is manual as of schema v4 (F38-D4): the link to a saved
/// document that [Reminders] once carried (`document_id`, F09-T03) is gone —
/// dropped by the v4 migration along with every reminder it still pointed at.
/// [isManual] stays regardless (F38-D5): it drives whether
/// `ReminderFormState` requires a time, which has nothing to do with where a
/// reminder came from.
@DataClassName('ReminderRow')
@TableIndex(name: 'reminders_event_date', columns: {#eventDate})
@TableIndex(name: 'reminders_status', columns: {#status})
class Reminders extends Table {
  TextColumn get id => text()();

  /// Editable by the user; prefilled from the document's title when created
  /// from a date (F09-T03).
  TextColumn get title => text()();

  /// The user's own note — «ملاحظة». `null` until they write one.
  TextColumn get description => text().nullable()();

  /// The calendar day the *event* falls on — the deadline or appointment
  /// itself, not when the notification fires. Stored the same way
  /// `DocumentDates.date` is: the day as printed, with no timezone
  /// conversion (`document_date_label.dart`).
  DateTimeColumn get eventDate => dateTime()();

  /// Minutes since midnight on [eventDate], or `null` when the paper gave no
  /// hour (F09-T05/T06). Never guessed — a missing time stays missing here
  /// even though every alert on the reminder still needs a real clock time.
  IntColumn get eventMinuteOfDay => integer().nullable()();

  TextColumn get status => textEnum<ReminderStatus>()();

  /// `true` for a hand-entered reminder (F09-T04), `false` for one created
  /// from a document's date (F09-T03). Drives copy ("من ورقة" vs plain) but
  /// nothing structural — both kinds share every other column.
  BoolColumn get isManual => boolean()();

  DateTimeColumn get createdAt => dateTime()();

  /// Last edit to title, description, event fields, or its alert set.
  DateTimeColumn get updatedAt => dateTime()();

  /// When [status] became [ReminderStatus.completed]. `null` while pending.
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One moment a reminder should notify at — up to three per reminder
/// (F09-T08), each independently cancellable.
///
/// [scheduledAt] is a real instant (UTC), unlike `Reminders.eventDate`: it is
/// *when the OS should fire*, already resolved from whatever Cairo wall-clock
/// time the user chose (`cairoInstant`), not a calendar day that still needs
/// a clock reading attached.
@DataClassName('ReminderAlertRow')
@TableIndex(name: 'reminder_alerts_reminder', columns: {#reminderId})
class ReminderAlerts extends Table {
  TextColumn get id => text()();

  TextColumn get reminderId =>
      text().references(Reminders, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get scheduledAt => dateTime()();

  /// The id this alert was handed to `flutter_local_notifications` under —
  /// needed to cancel or reschedule the exact OS-side alarm later (F09-T10).
  /// A stable positive hash of [id] rather than a fresh int, so recomputing
  /// it never requires a lookup.
  IntColumn get notificationId => integer()();

  TextColumn get status => textEnum<ReminderAlertStatus>()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
