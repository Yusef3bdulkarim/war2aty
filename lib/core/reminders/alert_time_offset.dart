/// A quick way to say "how long before the event" an alert fires.
///
/// The presets the reminder form offers when the event has a known time
/// (F09-T05) — matching the chips the design draws on both the
/// create-from-document and manual-reminder screens. [applyTo] needs a real
/// event instant, which only exists when the event has a time attached;
/// with no event time the form skips these entirely and asks for an
/// absolute date and time instead (F09-T06) — there is nothing to offset
/// *from*.
///
/// Pure Dart, no Flutter import.
enum AlertTimeOffset {
  /// The alert fires at the same instant as the event — the manual-reminder
  /// form's own default (F09-T04): if you typed a date and time by hand, the
  /// most natural first alert is exactly then.
  atEventTime(Duration.zero),

  twoHoursBefore(Duration(hours: 2)),

  /// The create-from-document form's default (F09-T03) — the design's own
  /// pre-checked choice for a date read off a paper.
  oneDayBefore(Duration(days: 1)),

  threeDaysBefore(Duration(days: 3));

  const AlertTimeOffset(this.before);

  /// How long before the event this fires. [Duration.zero] for
  /// [atEventTime].
  final Duration before;

  /// The alert instant this offset resolves to, given the event's own
  /// instant (UTC).
  DateTime applyTo(DateTime eventInstant) => eventInstant.subtract(before);
}
