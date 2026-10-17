import '../time/cairo_day.dart';

/// 09:00, as minutes since midnight — the hour every quick reminder lands on.
///
/// Early enough to be useful for a thing due that day, late enough not to
/// wake anyone. The user can move it in the form before saving; this is only
/// where the pre-filled form starts.
const int kQuickReminderMinuteOfDay = 9 * 60;

/// The three ready-made event dates the empty reminders list offers (F29).
///
/// Named by what the user reads, not by the arithmetic: «بكرة», «بعد أسبوع»,
/// «آخر الشهر». The label itself lives in `AppStrings` — this enum is only
/// the key a widget switches on.
enum QuickReminderDate { tomorrow, nextWeek, endOfMonth }

/// One ready-made date, resolved against a particular "now".
///
/// Carries the two fields a reminder is created from — a calendar day and a
/// minute within it — rather than an instant, because that is what
/// `CreateManualReminder` and the form state both speak.
final class QuickReminderSlot {
  const QuickReminderSlot({
    required this.kind,
    required this.eventDate,
    required this.eventMinuteOfDay,
  });

  final QuickReminderDate kind;

  /// The calendar day, as a local midnight — the same shape
  /// `showDatePicker` hands the manual form, and the shape Drift round-trips
  /// without shifting a day.
  ///
  /// Deliberately **not** `DateTime.utc`: `formatDocumentDate` and the Drift
  /// column both read `.year`/`.month`/`.day` as they stand, so a UTC
  /// midnight would come back a day early for any device west of UTC.
  final DateTime eventDate;

  /// Always [kQuickReminderMinuteOfDay] today, but carried explicitly: the
  /// form needs a value for it, and a caller should not have to know which
  /// constant it was.
  final int eventMinuteOfDay;

  /// The real instant this falls on, on the Cairo clock — DST-aware, the
  /// same path `Reminder.eventInstant` takes.
  DateTime get eventInstant => cairoInstantOf(eventDate, eventMinuteOfDay);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickReminderSlot &&
          other.kind == kind &&
          other.eventDate == eventDate &&
          other.eventMinuteOfDay == eventMinuteOfDay;

  @override
  int get hashCode => Object.hash(kind, eventDate, eventMinuteOfDay);

  @override
  String toString() =>
      'QuickReminderSlot(${kind.name}, '
      '${eventDate.year}-${eventDate.month}-${eventDate.day}, '
      '$eventMinuteOfDay)';
}

/// The three quick dates, in the order the empty state lists them.
///
/// Every day is a **Cairo** calendar day: this app's users are in Egypt and
/// every other day boundary in it (the usage counter, the due labels) is
/// Cairo's, so "tomorrow" cannot mean the device's tomorrow.
///
/// Read through [cairoWallClockOf] — the real, DST-aware zone — rather than
/// [cairoDateOf], whose fixed +2 offset names the previous day for the first
/// hour after midnight while Egypt is on summer time. That offset is right
/// for the usage-day boundary it was written for; it is not right for
/// deciding what day it is for the user.
///
/// Every slot is guaranteed to resolve to an instant **strictly in the
/// future**, so the alert the form seeds at the event's own time is never
/// already in the past (which would show the user's first reminder as
/// «فائت» the moment they saved it). Only [QuickReminderDate.endOfMonth] can
/// need that correction — see [_endOfMonth].
///
/// [now] is for tests; production passes nothing.
List<QuickReminderSlot> quickReminderSlots({DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = cairoWallClockOf(clock);

  QuickReminderSlot slot(QuickReminderDate kind, DateTime date) =>
      QuickReminderSlot(
        kind: kind,
        eventDate: date,
        eventMinuteOfDay: kQuickReminderMinuteOfDay,
      );

  return [
    slot(QuickReminderDate.tomorrow, _addDays(today, 1)),
    slot(QuickReminderDate.nextWeek, _addDays(today, 7)),
    slot(QuickReminderDate.endOfMonth, _endOfMonth(today, clock)),
  ];
}

/// [days] after the Cairo day [today] falls on, as a local midnight.
///
/// Built from the calendar fields rather than by adding a [Duration]: Dart
/// rolls an out-of-range day into the next month on its own
/// (`DateTime(2026, 10, 32)` is 1 November), so this gets month ends, short
/// months and leap days right without a special case, and without a DST
/// transition turning "+1 day" into 23 or 25 hours.
DateTime _addDays(DateTime today, int days) =>
    DateTime(today.year, today.month, today.day + days);

/// The last day of the Cairo month, rolled forward a month when 09:00 on it
/// has already gone by.
///
/// On the 31st at noon, "the end of the month" is a few hours in the past —
/// saving that would hand the user a reminder that is instantly missed. The
/// row shows its resolved date underneath the label, so the user sees it is
/// next month's.
///
/// `DateTime(y, m + 1, 0)` is the idiom for "last day of month m": day zero
/// of the following month. February and leap years come out of it for free.
DateTime _endOfMonth(DateTime today, DateTime clock) {
  final thisMonth = DateTime(today.year, today.month + 1, 0);
  if (cairoInstantOf(thisMonth, kQuickReminderMinuteOfDay).isAfter(clock)) {
    return thisMonth;
  }
  return DateTime(today.year, today.month + 2, 0);
}
