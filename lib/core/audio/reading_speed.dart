/// A reading-speed choice offered from the reader's options sheet —
/// «سرعة القراءة» (F10-T06).
///
/// `TextToSpeechService.setSpeechRate` takes its own 0.0 (slowest) to 1.0
/// (fastest) scale with no "normal" point of its own — `flutter_tts`
/// documents it only as slowest-to-fastest, normalized per platform. [rate]
/// anchors each option's on-screen multiplier around 0.5, the pace
/// `flutter_tts`'s own `getSpeechRateValidRange` reports as `normal` on
/// Android and iOS alike, so [normal] reads at each platform's ordinary pace
/// rather than at either extreme of the raw scale.
enum ReadingSpeed {
  /// «0.75x».
  slower(rate: 0.375, label: '0.75x'),

  /// «1x» — the default, both here and for a fresh reading.
  normal(rate: 0.5, label: '1x'),

  /// «1.25x».
  faster(rate: 0.625, label: '1.25x'),

  /// «1.5x».
  fastest(rate: 0.75, label: '1.5x');

  const ReadingSpeed({required this.rate, required this.label});

  /// What to hand `TextToSpeechService.setSpeechRate`.
  final double rate;

  /// The literal number the pill shows. Not routed through the app's own
  /// localized strings — the multiplier notation reads the same in Arabic
  /// and English, the same reason `TtsVoice`'s device-reported fields skip
  /// it too.
  final String label;
}
