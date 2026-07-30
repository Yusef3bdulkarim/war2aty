import '../localization/app_strings.dart';
import '../time/cairo_day.dart';
import '../time/document_date_label.dart';

/// Renders when a reminder is due, in the user's words.
///
/// Lives in `core/` because Home (F02) and the reminders list (F09) must word
/// the same instant identically. It composes localized fragments rather than
/// building sentences itself, so Arabic and English each keep their own word
/// order.
///
/// Days are compared on the Africa/Cairo calendar, matching how the rest of
/// the app groups by day — a reminder at 1am Cairo is "today", not "tomorrow",
/// regardless of the device's timezone.
///
/// Known gap: a reminder whose time has already passed is worded like any
/// other dated one ("On 20/7 at …") rather than as overdue. Home only ever
/// shows the *next* reminder, so it does not hit this; the missed-reminder
/// wording belongs to F09, where the design specifies that state.
String reminderDueLabel(AppStrings s, DateTime dueAt, {DateTime? now}) {
  final today = cairoDateOf(now ?? DateTime.now());
  final dueDay = cairoDateOf(dueAt);
  final time = formatClockTime(s, dueAt);

  final daysAway = dueDay.difference(today).inDays;
  return switch (daysAway) {
    0 => s.reminderDueToday(time),
    1 => s.reminderDueTomorrow(time),
    // The design shows no example past tomorrow, so this stays a plain
    // numeric day. Weekday and month names arrive with F09's reminders list,
    // where the design does specify them.
    _ => s.reminderDueOn(_shortDate(dueAt), time),
  };
}

/// A 12-hour clock reading of [instant], on the Cairo clock.
///
/// Shares its wording with the times printed on a paper — a reminder for
/// «10:00 صباحًا» must not read differently from the appointment it is for.
String formatClockTime(AppStrings s, DateTime instant) {
  final cairo = cairoLocalOf(instant);
  return formatWallClockTime(s, cairo.hour, cairo.minute);
}

/// `25/8` — day then month, as both languages write a short date.
String _shortDate(DateTime instant) {
  final cairo = cairoLocalOf(instant);
  return '${cairo.day}/${cairo.month}';
}
