/// Egypt's standard offset from UTC (EET, UTC+2).
///
/// DST is intentionally not modelled here. The backend is the authority on
/// when the daily quota resets (§52/§55); this local helper only needs to agree
/// with it closely enough to group usage by day for display. Revisit if the app
/// ever has to enforce the reset offline.
const Duration kCairoUtcOffset = Duration(hours: 2);

/// [instant] as a wall-clock reading in Cairo.
///
/// The returned `DateTime` is nominally UTC but carries Cairo's date and time
/// fields, which is what display code needs — never use it for arithmetic
/// against real instants.
DateTime cairoLocalOf(DateTime instant) => instant.toUtc().add(kCairoUtcOffset);

/// The Africa/Cairo calendar date [instant] falls on, as a UTC-midnight
/// `DateTime` (date-only — no time component).
///
/// The daily analysis limit is counted per Cairo day, so a user in Cairo sees
/// their quota reset at local midnight regardless of device timezone.
DateTime cairoDateOf(DateTime instant) {
  final cairo = cairoLocalOf(instant);
  return DateTime.utc(cairo.year, cairo.month, cairo.day);
}

/// The instant (in UTC) at which the Cairo day containing [instant] ends —
/// i.e. when the quota next resets.
DateTime nextCairoResetAfter(DateTime instant) {
  return cairoDateOf(
    instant,
  ).add(const Duration(days: 1)).subtract(kCairoUtcOffset);
}

/// The reverse of [cairoLocalOf]: the real UTC instant at which the Cairo
/// wall clock reads [year]-[month]-[day] [hour]:[minute].
///
/// Reminders (F09) store *when a person means*, said in Cairo time — "24
/// August, 10 in the morning" — and have to turn that into an instant the OS
/// scheduler can fire on. This is the one place that conversion happens, so
/// every alert time is computed the same way.
DateTime cairoInstant(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) => DateTime.utc(year, month, day, hour, minute).subtract(kCairoUtcOffset);
