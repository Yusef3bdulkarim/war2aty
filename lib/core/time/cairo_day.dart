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
