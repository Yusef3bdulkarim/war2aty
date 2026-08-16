import '../localization/app_strings.dart';
import '../time/cairo_day.dart';
import '../time/document_date_label.dart';
import 'alert_time_offset.dart';

/// How an alert time reads in the form — either the preset it came from
/// ("قبل الموعد بيوم") or, for a hand-picked instant, the date and time
/// written out the same way a date off a paper is (`formatDocumentDate`).
///
/// [offset] is `null` for a custom time — the only case that needs
/// [instant] read out at all, since a preset's own label already says
/// everything relative to the event without repeating the number.
String alertTimeLabel(
  AppStrings s,
  DateTime instant, {
  required AlertTimeOffset? offset,
}) {
  if (offset != null) return alertOffsetLabel(s, offset);

  // DST-aware, matching how [instant] was scheduled — see
  // `formatClockTime`'s own doc for why this cannot be [cairoLocalOf].
  final cairo = cairoWallClockOf(instant);
  return '${formatDocumentDate(s, cairo)} — '
      '${formatWallClockTime(s, cairo.hour, cairo.minute)}';
}

/// The Arabic/English name of one [AlertTimeOffset] preset.
String alertOffsetLabel(AppStrings s, AlertTimeOffset offset) =>
    switch (offset) {
      AlertTimeOffset.atEventTime => s.reminderAlertOffsetAtEventTime,
      AlertTimeOffset.twoHoursBefore => s.reminderAlertOffsetTwoHours,
      AlertTimeOffset.oneDayBefore => s.reminderAlertOffsetOneDay,
      AlertTimeOffset.threeDaysBefore => s.reminderAlertOffsetThreeDays,
    };
