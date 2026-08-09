import '../../../../core/error/app_failure.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/time/cairo_day.dart';
import '../../../../core/utils/list_equality.dart';
import '../models/reminder_alert_draft.dart';

/// States of the reminder form (F09-T02), shared by the create-from-document
/// (F09-T03) and manual (F09-T04) flows.
sealed class ReminderFormState {
  const ReminderFormState();
}

/// Not a real value — a sentinel [ReminderFormEditing.copyWith] can compare
/// against with `identical`, so a field can be explicitly cleared to `null`
/// rather than "no change" being indistinguishable from "clear it".
const Object _unset = Object();

/// The form is open and editable.
final class ReminderFormEditing extends ReminderFormState {
  const ReminderFormEditing({
    required this.title,
    this.description,
    this.eventDate,
    this.eventMinuteOfDay,
    this.alerts = const [],
    this.documentId,
    this.documentTitle,
    required this.isManual,
    this.isSaving = false,
  });

  final String title;
  final String? description;

  /// `null` on a manual reminder until the user picks one (F09-T04); always
  /// set on a from-document reminder (F09-T03).
  final DateTime? eventDate;

  /// Minutes since midnight on [eventDate]. `null` means the paper gave no
  /// hour (F09-T06) — never possible on a manual reminder, whose form marks
  /// the time required.
  final int? eventMinuteOfDay;

  /// Up to three, in the order they were added (F09-T08).
  final List<ReminderAlertDraft> alerts;

  /// Set only when created from a document's date.
  final String? documentId;
  final String? documentTitle;

  final bool isManual;

  /// The write is in flight — the save button is disabled so one tap cannot
  /// become two reminders.
  final bool isSaving;

  /// The event's own instant (UTC), only once both a date and a time are
  /// known — what the alert picker offsets its presets from (F09-T05).
  DateTime? get eventInstant {
    final date = eventDate;
    final minute = eventMinuteOfDay;
    if (date == null || minute == null) return null;
    return cairoInstantOf(date, minute);
  }

  /// A manual reminder also requires a time — there is no paper to be silent
  /// about it, so the form does not offer F09-T06's "no time" state there.
  bool get _hasRequiredEventFields =>
      eventDate != null && (!isManual || eventMinuteOfDay != null);

  bool get canSave =>
      !isSaving &&
      title.trim().isNotEmpty &&
      _hasRequiredEventFields &&
      alerts.isNotEmpty;

  ReminderFormEditing copyWith({
    String? title,
    Object? description = _unset,
    Object? eventDate = _unset,
    Object? eventMinuteOfDay = _unset,
    List<ReminderAlertDraft>? alerts,
    bool? isSaving,
  }) {
    return ReminderFormEditing(
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      eventDate: identical(eventDate, _unset)
          ? this.eventDate
          : eventDate as DateTime?,
      eventMinuteOfDay: identical(eventMinuteOfDay, _unset)
          ? this.eventMinuteOfDay
          : eventMinuteOfDay as int?,
      alerts: alerts ?? this.alerts,
      documentId: documentId,
      documentTitle: documentTitle,
      isManual: isManual,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderFormEditing &&
          other.title == title &&
          other.description == description &&
          other.eventDate == eventDate &&
          other.eventMinuteOfDay == eventMinuteOfDay &&
          listEquals(other.alerts, alerts) &&
          other.documentId == documentId &&
          other.documentTitle == documentTitle &&
          other.isManual == isManual &&
          other.isSaving == isSaving;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    eventDate,
    eventMinuteOfDay,
    Object.hashAll(alerts),
    documentId,
    documentTitle,
    isManual,
    isSaving,
  );
}

/// The reminder was written. [reminder] is what the success screen (F09-T03)
/// and the details screen it opens into (F09-T12) show.
final class ReminderFormSaved extends ReminderFormState {
  const ReminderFormSaved(this.reminder);

  final Reminder reminder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderFormSaved && other.reminder == reminder;

  @override
  int get hashCode => reminder.hashCode;
}

/// The write failed. [editing] is the form as it stood, so the screen can
/// show it again rather than losing what the user typed.
final class ReminderFormSaveFailed extends ReminderFormState {
  const ReminderFormSaveFailed(this.editing, this.failure);

  final ReminderFormEditing editing;
  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderFormSaveFailed &&
          other.editing == editing &&
          other.failure == failure;

  @override
  int get hashCode => Object.hash(editing, failure);
}
