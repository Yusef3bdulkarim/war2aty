import '../localization/app_strings.dart';
import '../time/cairo_day.dart';
import '../time/document_date_label.dart';
import 'reminder.dart';
import 'reminder_due_label.dart';

/// What an OS notification for one of a reminder's alerts should say.
final class ReminderNotificationContent {
  const ReminderNotificationContent({required this.title, this.body});

  final String title;
  final String? body;
}

/// Builds the notification text for the alert of [reminder] that fires at
/// [firesAt] (F09-T10, reworded F25-T01).
///
/// The tone rises as the event gets closer — «فاضل 3 أيام», «بكرة آخر
/// ميعاد», «بعد ساعتين», «دلوقتي» — so each of a reminder's (up to three)
/// alerts reads differently. The stage is worked out from [firesAt], not from
/// the clock, so the same alert always gets the same words however many
/// times reconcile reschedules it.
///
/// [hideSensitiveDetails] is the setting's own current value (F09-T14,
/// default on) — this function does not read it itself, so it stays a pure
/// function of its arguments. Hidden says *when* but never the reminder's
/// real title or note: someone glancing at a lock screen may learn that
/// something is due tomorrow, never what it is or for how much (F25 locked
/// decision #2).
ReminderNotificationContent reminderNotificationContent(
  Reminder reminder,
  AppStrings strings, {
  required DateTime firesAt,
  required bool hideSensitiveDetails,
}) {
  final stage = _stageOf(reminder, firesAt);

  if (hideSensitiveDetails) {
    return ReminderNotificationContent(
      title: switch (stage) {
        _DaysAway(:final days) => strings.reminderNotificationHiddenTitleIn(
          strings.reminderNotificationDays(days),
        ),
        _Tomorrow() => strings.reminderNotificationHiddenTitleTomorrow,
        _HoursAway(:final hours) => strings.reminderNotificationHiddenTitleIn(
          strings.reminderNotificationHours(hours),
        ),
        _MinutesAway(:final minutes) =>
          strings.reminderNotificationHiddenTitleIn(
            strings.reminderNotificationMinutes(minutes),
          ),
        _Today() => strings.reminderNotificationHiddenTitleToday,
        _Now() => strings.reminderNotificationHiddenTitleNow,
      },
      body: strings.reminderNotificationHiddenBody,
    );
  }

  final title = reminder.title;
  final eventInstant = reminder.eventInstant;
  final time = eventInstant == null
      ? null
      : formatClockTime(strings, eventInstant);

  final (String heading, String? timing) = switch (stage) {
    _DaysAway(:final days) => (
      strings.reminderNotificationTitleDaysLeft(
        strings.reminderNotificationDays(days),
        title,
      ),
      _onDate(strings, reminder.eventDate, time),
    ),
    _Tomorrow() => (
      strings.reminderNotificationTitleTomorrow(title),
      time == null ? null : strings.reminderNotificationBodyAt(time),
    ),
    _HoursAway(:final hours) => (
      strings.reminderNotificationTitleIn(
        strings.reminderNotificationHours(hours),
        title,
      ),
      time == null ? null : strings.reminderNotificationBodyAt(time),
    ),
    _MinutesAway(:final minutes) => (
      strings.reminderNotificationTitleIn(
        strings.reminderNotificationMinutes(minutes),
        title,
      ),
      time == null ? null : strings.reminderNotificationBodyAt(time),
    ),
    _Today() => (strings.reminderNotificationTitleToday(title), null),
    _Now() => (
      strings.reminderNotificationTitleNow(title),
      strings.reminderNotificationBodyNow,
    ),
  };

  final note = reminder.description?.trim();
  final parts = [?timing, if (note != null && note.isNotEmpty) note];
  return ReminderNotificationContent(
    title: heading,
    body: parts.isEmpty ? null : parts.join(' '),
  );
}

String _onDate(AppStrings s, DateTime eventDate, String? time) {
  final date = formatDayMonth(s, eventDate);
  return time == null
      ? s.reminderNotificationBodyOn(date)
      : s.reminderNotificationBodyOnAt(date, time);
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
