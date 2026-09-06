import 'package:timezone/timezone.dart' as tz;

const Duration kCairoUtcOffset = Duration(hours: 2);
DateTime cairoLocalOf(DateTime instant) => instant.toUtc().add(kCairoUtcOffset);
DateTime cairoDateOf(DateTime instant) {
  final cairo = cairoLocalOf(instant);
  return DateTime.utc(cairo.year, cairo.month, cairo.day);
}

DateTime nextCairoResetAfter(DateTime instant) {
  return cairoDateOf(
    instant,
  ).add(const Duration(days: 1)).subtract(kCairoUtcOffset);
}

DateTime cairoInstant(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) => tz.TZDateTime(
  tz.getLocation('Africa/Cairo'),
  year,
  month,
  day,
  hour,
  minute,
).toUtc();

DateTime cairoInstantOf(DateTime date, int minuteOfDay) => cairoInstant(
  date.year,
  date.month,
  date.day,
  minuteOfDay ~/ 60,
  minuteOfDay % 60,
);

DateTime cairoWallClockOf(DateTime instant) =>
    tz.TZDateTime.from(instant.toUtc(), tz.getLocation('Africa/Cairo'));
