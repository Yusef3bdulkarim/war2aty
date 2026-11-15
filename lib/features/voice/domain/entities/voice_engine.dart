/// Which engine spoke a paper (F37).
///
/// Recorded per paper because the two tiers do not leave the same thing behind:
/// a Live read saves an `.m4a` and replays offline for free, while a device-TTS
/// read saves no file and has to be re-spoken every time. A saved paper's row
/// therefore has to say which one it was, or offline replay would look for a
/// file that was never written.
///
/// Supertonic was a third tier in F34's draft and is **cut** — 139 MB against
/// "minimise the APK", and the project is being discontinued.
enum VoiceEngine {
  /// Gemini Live: streamed, verbatim-checked, saved as AAC for offline replay.
  geminiLive,

  /// The device's own text-to-speech, via the existing `flutter_tts` stack.
  deviceTts;

  /// Whether a reading on this engine can be paused and resumed mid-paper
  /// (F37-T19).
  ///
  /// True for [geminiLive]: the producer cannot be paused — the service keeps
  /// streaming regardless — but the speaker can, and the rest of the paper
  /// accumulates until it is resumed, which is exactly what `PcmAudioSink`'s
  /// pause was built for.
  ///
  /// False for [deviceTts], and not because `flutter_tts` has no pause: it
  /// has one, and the 1.0.2 mini-player uses it. What it does not have is a
  /// resume that keeps counting. Android resumes by speaking a *fresh*
  /// utterance covering only the unread remainder, so the character offsets
  /// the engine then reports start from zero again — and those offsets are the
  /// whole of this tier's evidence for which card is being spoken (T18). A
  /// paused-and-resumed device read would therefore highlight the first card
  /// for the rest of the paper. Offering silence at the cost of the
  /// auto-scroll a non-reader depends on is not a trade this tier gets to
  /// make silently, so it declares it cannot pause and the screen offers stop
  /// instead. Making it pausable means tracking the resume offset inside the
  /// adapter — F40's call, with the owner.
  bool get canPauseMidRead => switch (this) {
    VoiceEngine.geminiLive => true,
    VoiceEngine.deviceTts => false,
  };
}
