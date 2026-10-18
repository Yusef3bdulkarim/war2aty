/// A text-to-speech voice available on the device.
///
/// [name] and [locale] are the two fields every platform reports and the two
/// that identify the voice. The rest describe it, and F30-T03 stopped
/// throwing them away: the reader used to take *the first* voice whose locale
/// matched and had no way to tell a fast on-device voice from one that has to
/// fetch its audio over the network — which is most of the owner's 1–3 second
/// delay (F30 RC-6), and the source of the transient network errors behind
/// RC-2.
final class TtsVoice {
  const TtsVoice({
    required this.name,
    required this.locale,
    this.quality = TtsVoiceQuality.unknown,
    this.latency = TtsVoiceLatency.unknown,
    this.networkRequired = false,
  });

  final String name;
  final String locale;

  /// How good the voice sounds, as the device reports it.
  final TtsVoiceQuality quality;

  /// How long the voice takes to start, as the device reports it.
  final TtsVoiceLatency latency;

  /// Whether the voice synthesises over the network rather than on the
  /// device.
  ///
  /// `false` when the platform does not say — iOS reports no such field, and
  /// its voices are on-device anyway. Preferring a voice where this is
  /// `false` is both the latency fix and, incidentally, the reason the
  /// privacy screen needed no change (F30 locked decision 9): a voice that
  /// synthesises on the device sends the text being read nowhere at all.
  final bool networkRequired;

  /// Identity is [name] and [locale] alone. The three fields above describe a
  /// voice rather than pick it out — two entries agreeing on name and locale
  /// are the same voice — and `DefaultReadingVoiceStore` only ever persisted
  /// those two, so a voice read back from storage still equals the one the
  /// device reported.
  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);

  @override
  String toString() => 'TtsVoice($name, $locale)';
}

/// How good a voice sounds, as the device reports it.
///
/// [rank] orders the values so a higher one sounds better. [unknown] sits
/// level with [normal] rather than last: a voice that did not report its
/// quality — every voice on a platform that does not send the field — should
/// not lose to one that reported itself as poor.
enum TtsVoiceQuality {
  veryLow(rank: 0),
  low(rank: 1),
  unknown(rank: 2),
  normal(rank: 2),
  high(rank: 3),
  veryHigh(rank: 4);

  const TtsVoiceQuality({required this.rank});

  final int rank;
}

/// How long a voice takes to start speaking, as the device reports it.
///
/// [rank] orders the values so a **lower** one starts sooner — the opposite
/// direction to [TtsVoiceQuality.rank], because that is the direction the
/// underlying measures run in. [unknown] sits level with [normal], for the
/// reason [TtsVoiceQuality.unknown] does.
enum TtsVoiceLatency {
  veryLow(rank: 0),
  low(rank: 1),
  unknown(rank: 2),
  normal(rank: 2),
  high(rank: 3),
  veryHigh(rank: 4);

  const TtsVoiceLatency({required this.rank});

  final int rank;
}
