import '../time/cairo_day.dart';
import '../utils/list_equality.dart';
import 'reminder_alert.dart';
import 'reminder_alert_status.dart';
import 'reminder_status.dart';

/// A thing the user wants to be reminded about (F09).
///
/// Either created from a date the analysis found on a saved document
/// ([isManual] `false`, [documentId] set — F09-T03) or entered by hand
/// ([isManual] `true`, [documentId] `null` — F09-T04). Both kinds share every
/// other field: a reminder does not know or care where it came from once it
/// exists.
///
/// Pure Dart, no Flutter import.
final class Reminder {
  const Reminder({
    required this.id,
    this.documentId,
    required this.title,
    this.description,
    required this.eventDate,
    this.eventMinuteOfDay,
    required this.status,
    required this.isManual,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.alerts = const [],
  });

  final String id;

  /// The saved document this was created from, or `null` for a manual
  /// reminder.
  final String? documentId;

  final String title;

  /// The user's own note. `null` until they write one.
  final String? description;

  /// The calendar day the event itself falls on — not when a notification
  /// fires. Stored as printed on the paper, with no timezone conversion
  /// (matches `AnalysisDate.date`).
  final DateTime eventDate;

  /// Minutes since midnight on [eventDate], or `null` when the paper (or the
  /// user, for a manual reminder) gave no hour. Never guessed (F09-T05/T06).
  final int? eventMinuteOfDay;

  final ReminderStatus status;

  final bool isManual;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// When [status] became [ReminderStatus.completed]. `null` while pending.
  final DateTime? completedAt;

  /// Up to three, earliest first (F09-T08).
  final List<ReminderAlert> alerts;

  bool get hasEventTime => eventMinuteOfDay != null;

  /// The event's own instant (UTC), only meaningful when [hasEventTime] —
  /// the reverse of what `AnalysisDate.time` starts from, combined with
  /// [eventDate] the same way any other Cairo date+time is (`cairoInstant`).
  DateTime? get eventInstant {
    final minute = eventMinuteOfDay;
    if (minute == null) return null;
    return cairoInstant(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      minute ~/ 60,
      minute % 60,
    );
  }

  /// The soonest alert still expected to fire, or `null` once every alert has
  /// been cancelled. What the list row and Home's upcoming card show.
  ReminderAlert? get nextAlert {
    final upcoming = alerts.where((a) => a.status.isActive).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Pending, with every one of its alerts already in the past — «الفائتة»
  /// (F09-T11). Not a stored state (see [ReminderStatus]): a reminder with no
  /// alerts left to fire is "missed" the instant the clock passes its last
  /// one, and computing that here means it can never drift out of sync with
  /// what time it actually is.
  ///
  /// A reminder with no alerts at all (should not normally happen — creation
  /// requires at least one) is never overdue: there is nothing it missed.
  bool isOverdue({DateTime? now}) {
    if (!status.isPending || alerts.isEmpty) return false;
    final clock = now ?? DateTime.now();
    final relevant = alerts.where(
      (a) => a.status != ReminderAlertStatus.cancelled,
    );
    if (relevant.isEmpty) return false;
    return relevant.every((a) => !a.scheduledAt.isAfter(clock));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          other.id == id &&
          other.documentId == documentId &&
          other.title == title &&
          other.description == description &&
          other.eventDate == eventDate &&
          other.eventMinuteOfDay == eventMinuteOfDay &&
          other.status == status &&
          other.isManual == isManual &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.completedAt == completedAt &&
          listEquals(other.alerts, alerts);

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    title,
    description,
    eventDate,
    eventMinuteOfDay,
    status,
    isManual,
    createdAt,
    updatedAt,
    completedAt,
    Object.hashAll(alerts),
  );

  // Title and description are content the user typed about a real paper or
  // event and must never reach a log (privacy §7).
  @override
  String toString() => 'Reminder($id, $status, ${alerts.length} alerts)';
}
