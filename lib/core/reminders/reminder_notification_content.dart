import '../localization/app_strings.dart';
import '../time/cairo_day.dart';
import 'reminder.dart';
import 'reminder_due_label.dart';

/// What an OS notification for one of a reminder's alerts should say.
final class ReminderNotificationContent {
  const ReminderNotificationContent({required this.title, required this.body});

  final String title;
  final String body;
}

/// Builds the notification text for the alert of [reminder] that fires at
/// [firesAt] (F09-T10, reworded F25-T01, restructured F25-T08).
///
/// **Title, in both modes:** how close the event is, then the reminder's own
/// title — «فاضل 3 أيام: …», «بكرة آخر ميعاد: …», «بعد ساعتين: …»,
/// «دلوقتي: …». The stage is worked out from [firesAt], not from the clock,
/// so the same alert always gets the same words however many times
/// reconcile reschedules it.
///
/// **Body:** the event's time, and — only when details are shown — the
/// user's note after it («10:00 صباحًا • السداد عن طريق فوري»). With no note
/// the time reads «الساعة 10:00 صباحًا»; with no time, the note alone, or
/// «اضغط للمتابعة» when there is nothing else to say. The time is never
/// invented for an event that has none.
///
/// [hideSensitiveDetails] is the setting's own current value (F09-T14,
/// default on) — this function does not read it itself, so it stays a pure
/// function of its arguments. Since F25-T08 (the owner's call, 2026-10-04)
/// hiding keeps only the user's note off the lock screen: the title is shown
/// as-is in both modes.
ReminderNotificationContent reminderNotificationContent(
  Reminder reminder,
  AppStrings strings, {
  required DateTime firesAt,
  required bool hideSensitiveDetails,
}) {
  final eventInstant = reminder.eventInstant;
  final time = eventInstant == null
      ? null
      : formatClockTime(strings, eventInstant);

  return ReminderNotificationContent(
    title: _titleOf(_stageOf(reminder, firesAt), reminder.title, strings),
    body: hideSensitiveDetails
        ? time ?? strings.reminderNotificationTapToContinue
        : _shownBody(time, reminder.description?.trim(), strings),
  );
}

String _titleOf(_Stage stage, String title, AppStrings s) => switch (stage) {
  _DaysAway(:final days) => s.reminderNotificationTitleDaysLeft(
    s.reminderNotificationDays(days),
    title,
  ),
  _Tomorrow() => s.reminderNotificationTitleTomorrow(title),
  _HoursAway(:final hours) => s.reminderNotificationTitleIn(
    s.reminderNotificationHours(hours),
    title,
  ),
  _MinutesAway(:final minutes) => s.reminderNotificationTitleIn(
    s.reminderNotificationMinutes(minutes),
    title,
  ),
  _Today() => s.reminderNotificationTitleToday(title),
  _Now() => s.reminderNotificationTitleNow(title),
};

String _shownBody(String? time, String? note, AppStrings s) {
  final hasNote = note != null && note.isNotEmpty;
  return switch ((time, hasNote)) {
    (final String time, true) => s.reminderNotificationBodyTimeAndNote(
      time,
      note!,
    ),
    (final String time, false) => s.reminderNotificationBodyAt(time),
    (null, true) => note!,
    (null, false) => s.reminderNotificationTapToContinue,
  };
}

/// How far [firesAt] is from [reminder]'s event: whole Cairo calendar days
/// first, then — on the event's own day, when it has a time — hours or
/// minutes.
_Stage _stageOf(Reminder reminder, DateTime firesAt) {
  // DST-aware ([cairoWallClockOf], not [cairoDateOf]): an alert at 23:30
  // Cairo summer time is still on that day, not the next.
  final firesWallClock = cairoWallClockOf(firesAt);
  final firesDay = DateTime.utc(
    firesWallClock.year,
    firesWallClock.month,
    firesWallClock.day,
  );
  // As printed on the paper, no timezone conversion (`Reminder.eventDate`).
  final eventDay = DateTime.utc(
    reminder.eventDate.year,
    reminder.eventDate.month,
    reminder.eventDate.day,
  );
  final daysAway = eventDay.difference(firesDay).inDays;

  if (daysAway >= 2) return _DaysAway(daysAway);
  if (daysAway == 1) return const _Tomorrow();
  // An alert after the event's day only happens once a missed reminder is
  // snoozed — it is due, the same as one firing on time.
  if (daysAway < 0) return const _Now();

  final eventInstant = reminder.eventInstant;
  if (eventInstant == null) return const _Today();

  final minutes = eventInstant.difference(firesAt).inMinutes;
  if (minutes <= 0) return const _Now();
  if (minutes < 60) return _MinutesAway(minutes);
  return _HoursAway((minutes / 60).round());
}

sealed class _Stage {
  const _Stage();
}

final class _DaysAway extends _Stage {
  const _DaysAway(this.days);
  final int days;
}

final class _Tomorrow extends _Stage {
  const _Tomorrow();
}

final class _HoursAway extends _Stage {
  const _HoursAway(this.hours);
  final int hours;
}

final class _MinutesAway extends _Stage {
  const _MinutesAway(this.minutes);
  final int minutes;
}

final class _Today extends _Stage {
  const _Today();
}

final class _Now extends _Stage {
  const _Now();
}
