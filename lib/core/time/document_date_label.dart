import '../localization/app_strings.dart';

/// A date read off a paper, written out — `25 أغسطس 2026` / `25 August 2026`.
///
/// [date]'s fields are used as they stand, with no timezone conversion: a date
/// on a bill is a calendar day the printer wrote, not an instant, and shifting
/// it could move it to the day before the deadline.
String formatDocumentDate(AppStrings s, DateTime date) =>
    '${date.day} ${s.monthName(date.month)} ${date.year}';

/// A wall-clock reading such as `10:00 صباحًا` / `10:00 PM`.
///
/// Hand-rolled rather than pulled from `intl`: the app needs one format, in
/// two languages, and the Egyptian wording comes from [AppStrings] anyway.
String formatWallClockTime(AppStrings s, int hour, int minute) {
  // 0 and 12 both read as 12 on a 12-hour clock.
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final isMorning = hour < 12;

  return '$displayHour:${minute.toString().padLeft(2, '0')} '
      '${isMorning ? s.timeAm : s.timePm}';
}
