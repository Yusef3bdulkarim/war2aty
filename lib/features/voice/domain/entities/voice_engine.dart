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
  deviceTts,
}
