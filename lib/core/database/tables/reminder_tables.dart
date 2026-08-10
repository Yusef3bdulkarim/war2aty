import 'package:drift/drift.dart';

import '../../reminders/reminder_alert_status.dart';
import '../../reminders/reminder_status.dart';
import 'document_tables.dart';

/// A thing the user wants to be reminded about (F09).
///
/// One row per reminder, either linked to a [Documents] row it was created
/// from ([documentId] set) or entered by hand ([documentId] `null`). The
/// times it fires live in [ReminderAlerts], a separate table, because a
/// reminder can carry up to three of them (F09-T08) — the *event* below is
/// singular, the *alerts* about it are not.
///
/// Deleting the linked document cascades onto this row: once F09-T10's
/// scheduler cancels its OS-side alerts (see `DriftDocumentsRepository`'s
/// document-delete path), there is nothing left worth keeping a reminder for
/// — the paper it was about is gone. A manual reminder has no such row to
/// cascade from and survives its (non-existent) link forever.
///
/// No `document_title_snapshot` column, unlike the plan's original sketch:
/// the cascade above means a reminder can never outlive the document it
/// points at, so the live title is always one join away and a copy would
/// only be one more place for it to go stale.
@DataClassName('ReminderRow')
@TableIndex(name: 'reminders_event_date', columns: {#eventDate})
@TableIndex(name: 'reminders_status', columns: {#status})
@TableIndex(name: 'reminders_document', columns: {#documentId})
class Reminders extends Table {
  TextColumn get id => text()();

  /// The saved document this was created from, or `null` for a manual
  /// reminder (F09-T04).
  TextColumn get documentId => text().nullable().references(
    Documents,
    #id,
    onDelete: KeyAction.cascade,
  )();

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
