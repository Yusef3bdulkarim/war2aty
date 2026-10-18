/// Why the reading engine stopped, as the engine itself reported it
/// (F30-T08).
///
/// Until T08 there was no such thing: `FlutterTtsTextToSpeechService`
/// registered `setErrorHandler((_) => ...)` and threw the payload away, so
/// every engine error — a voice still downloading, a network hiccup, a dead
/// engine — became the same unexplained «حصلت مشكلة. جرّب تاني.». Two things
/// followed from that, both of them F30 RC-2: the user was made to retry by
/// hand what the app could have retried itself (the owner's reading worked on
/// the third tap), and nothing about any of it reached F27's logging, which
/// left production blind.
///
/// A closed set, not the engine's raw message: the platform sends free text
/// («Error from TextToSpeech (speak) - -6»), and free text is exactly what
/// must never reach a log line (§51) or a `switch`. Everything the app needs
/// to decide is [isTransient]; [logCode] is what F27's `errorCode` field
/// carries.
///
/// The values mirror `android.speech.tts.TextToSpeech`'s own constants. iOS
/// has no counterpart — `flutter_tts`'s iOS side reports no error at all —
/// so every value here describes an Android condition, and a platform that
/// says nothing lands on [unknown].
enum TtsErrorCode {
  /// `ERROR_NOT_INSTALLED_YET` (-9) — the voice data is still downloading,
  /// which is what a phone does the first time a voice is used. Retrying a
  /// moment later is the whole fix.
  notInstalledYet(logCode: 'TTS_NOT_INSTALLED_YET', isTransient: true),

  /// `ERROR_NETWORK` (-6) — a network-synthesised voice could not fetch its
  /// audio. Common here, and not a defect of the device: Google's Arabic
  /// voices are routinely network ones, which is also why T05 prefers an
  /// offline voice in the first place.
  network(logCode: 'TTS_NETWORK', isTransient: true),

  /// `ERROR_NETWORK_TIMEOUT` (-7) — the same fetch, slow rather than
  /// refused.
  networkTimeout(logCode: 'TTS_NETWORK_TIMEOUT', isTransient: true),

  /// `ERROR_SYNTHESIS` (-3) — the engine could not turn this text into
  /// speech. Handing it the same text again produces the same answer.
  synthesis(logCode: 'TTS_SYNTHESIS', isTransient: false),

  /// `ERROR_SERVICE` (-4) — the engine's own service failed.
  service(logCode: 'TTS_SERVICE', isTransient: false),

  /// `ERROR_OUTPUT` (-5) — the engine could not play the audio out.
  output(logCode: 'TTS_OUTPUT', isTransient: false),

  /// `ERROR_INVALID_REQUEST` (-8) — the engine rejected the request itself.
  invalidRequest(logCode: 'TTS_INVALID_REQUEST', isTransient: false),

  /// The engine reported an error without a code we recognise: the generic
  /// `ERROR` (-1), a code from some future Android, or the older
  /// `onError(utteranceId)` callback, which carries no code at all.
  ///
  /// Transient on purpose. "We do not know" must not be told to the user as
  /// «القراءة بصوت مش متاحة» — that sentence is only honest when the engine
  /// actually said so — and it is the kind the owner retried by hand until it
  /// worked. Distinct from a [logCode] of `TTS`, which is the wrapper's own
  /// exception paths, where the engine never reported anything at all.
  unknown(logCode: 'TTS_UNKNOWN', isTransient: true);

  const TtsErrorCode({required this.logCode, required this.isTransient});

  /// The stable, content-free code F27's logging records — same shape as
  /// `errorCodeOf`'s values, which is where it is read from.
  final String logCode;

  /// Whether trying the same reading again could plausibly succeed.
  ///
  /// Drives both halves of RC-2's fix: the retryable kind is retried once in
  /// silence (T16) and, if that fails too, says «جرّب تاني»; the permanent
  /// kind stops and says the reading is not available, because asking
  /// someone to retry what cannot work is worse than telling them it cannot.
  final bool isTransient;
}
