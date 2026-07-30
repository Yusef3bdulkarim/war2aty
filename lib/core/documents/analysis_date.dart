import 'confidence_band.dart';

/// What a date on the document means — API_CONTRACT §30.2.
enum DateRole {
  /// Payment due date, submission deadline.
  deadline,

  /// Scheduled meeting, visit, reservation time.
  appointment,

  /// When the document was created or issued.
  issued,

  /// Expiration date — licence, certificate, offer.
  expiry,

  /// General event date — exam, ceremony.
  event,

  /// Start of a billing or coverage period.
  periodStart,

  /// End of a billing or coverage period.
  periodEnd,
}

/// A wall-clock time of day, with no date and no time zone attached.
///
/// `TimeOfDay` would do the job but lives in Flutter, which the domain layer
/// must not import.
final class AnalysisTime {
  const AnalysisTime({required this.hour, required this.minute});

  /// 0–23.
  final int hour;

  /// 0–59.
  final int minute;

  /// `HH:mm`, the same shape the contract uses on the wire.
  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  // The time is read off the paper — an appointment hour is document content
  // like any other (privacy §7). [formatted] is for display, never for logs.
  @override
  String toString() => 'AnalysisTime(hh:mm)';
}

/// A date the analysis found, with what it's for and whether it's worth a
/// reminder.
final class AnalysisDate {
  const AnalysisDate({
    required this.label,
    required this.date,
    this.time,
    required this.role,
    required this.isReminderWorthy,
    required this.confidence,
  });

  /// Arabic label, e.g. «آخر موعد للسداد».
  final String label;

  /// The calendar day, at local midnight. Combine with [time] before
  /// scheduling anything.
  final DateTime date;

  /// Time of day, or `null` when the paper gives a day but no hour.
  ///
  /// The distinction is load-bearing: scheduling a reminder without a time
  /// has to ask the user for one rather than guessing (see
  /// `MissingReminderTimeFailure`).
  final AnalysisTime? time;

  final DateRole role;

  /// Whether the analysis thinks this date is worth reminding about.
  ///
  /// A suggestion only — no reminder is ever scheduled without the user
  /// reviewing it first (privacy rule: no automatic reminders).
  final bool isReminderWorthy;

  final ConfidenceBand confidence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisDate &&
          other.label == label &&
          other.date == date &&
          other.time == time &&
          other.role == role &&
          other.isReminderWorthy == isReminderWorthy &&
          other.confidence == confidence;

  @override
  int get hashCode =>
      Object.hash(label, date, time, role, isReminderWorthy, confidence);

  // Label, date and time all omitted: the label is AI-generated text about
  // this document, not a fixed field name, so it is content too (§7).
  @override
  String toString() =>
      'AnalysisDate($role, reminderWorthy=$isReminderWorthy, $confidence)';
}
