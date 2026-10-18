import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/audio_reader/domain/entities/tts_event.dart';
import '../../features/audio_reader/domain/usecases/offerable_reading_modes.dart';
import '../../features/audio_reader/domain/usecases/pause_reading.dart';
import '../../features/audio_reader/domain/usecases/resume_reading.dart';
import '../../features/audio_reader/domain/usecases/set_reading_speed.dart';
import '../../features/audio_reader/domain/usecases/start_raw_reading.dart';
import '../../features/audio_reader/domain/usecases/start_reading.dart';
import '../../features/audio_reader/domain/usecases/stop_reading.dart';
import '../../features/audio_reader/domain/usecases/warm_up_reader.dart';
import '../../features/audio_reader/domain/usecases/watch_reading_events.dart';
import '../documents/analysis_result.dart';
import '../documents/reading_mode.dart';
import '../error/app_failure.dart';
import '../localization/app_strings.dart';
import 'audio_reader_state.dart';
import 'reading_speed.dart';
import 'usecases/get_default_reading_speed.dart';
import 'usecases/open_system_tts_settings.dart';

/// Drives the result screen's mini-player: what [ReadingMode] is reading, and
/// starting/stopping the engine behind it (F10-T04).
///
/// Depends on its use cases only (architecture rule). Lives in `core/` rather
/// than the `audio_reader` feature because the result page (owned by the
/// `analysis` feature) drives the mini-player inline in its own layout, and a
/// feature screen never imports another feature directly — the same reason
/// `AudioMiniPlayerBar` and `AudioOptionsSheet` sit in `core/widgets/`.
///
/// The result it reads from is handed in on every [start] rather than held by
/// the cubit, since the same instance also answers the mode-picker sheet
/// reopened from «خيارات» partway through a reading.
final class AudioReaderCubit extends Cubit<AudioReaderState> {
  AudioReaderCubit(
    this._startReading,
    this._startRawReading,
    this._stopReading,
    this._pauseReading,
    this._resumeReading,
    this._setReadingSpeed,
    this._watchReadingEvents,
    this._getDefaultReadingSpeed,
    this._warmUpReader,
    this._openSystemTtsSettings,
    this._offerableReadingModes,
  ) : super(const AudioReaderIdle()) {
    _eventsSubscription = _watchReadingEvents().listen(_onEvent);
    // Fire-and-forget on purpose (F30-T06): this cubit is built as the screen
    // that owns the mini-player mounts, which is seconds before anyone
    // reaches for «الاستماع», and the warm-up has nothing to report. See
    // [WarmUpReader] for what it is buying.
    unawaited(_warmUpReader());
  }

  final StartReading _startReading;
  final StartRawReading _startRawReading;
  final StopReading _stopReading;
  final PauseReading _pauseReading;
  final ResumeReading _resumeReading;
  final SetReadingSpeed _setReadingSpeed;
  final WatchReadingEvents _watchReadingEvents;

  /// «سرعة القراءة الافتراضية» (F11-T07) — read once per fresh sheet open,
  /// not cached: Settings can change it between one reading and the next.
  final GetDefaultReadingSpeed _getDefaultReadingSpeed;

  /// Primes the engine the moment this cubit exists, so the first tap is not
  /// the one that pays for it (F30-T06).
  final WarmUpReader _warmUpReader;

  /// The way out of [NoArabicVoiceFailure] — the one reading failure the
  /// user can fix themselves (F30-T07).
  final OpenSystemTtsSettings _openSystemTtsSettings;

  /// Which modes this paper actually has something to read for (F30-T19).
  final OfferableReadingModes _offerableReadingModes;

  /// Listens for the rest of this cubit's life — one shared engine, one
  /// subscription — and is cancelled in [close].
  late final StreamSubscription<TtsEvent> _eventsSubscription;

  /// The length (UTF-16 code units) of whatever [start] most recently began
  /// reading — `null` before the first [start] and once a reading ends,
  /// either way. `TtsProgressed` events turn into an `AudioReaderReading`
  /// `progress` fraction against this (F10-T08); it is not part of the state
  /// itself since the UI only ever needs the fraction, not the raw length.
  int? _totalLength;

  /// The highest [AudioReaderReading.progress] reported so far this reading
  /// — reset alongside [_totalLength], and never allowed to fall.
  ///
  /// `flutter_tts`'s two platforms resume a paused utterance differently:
  /// iOS continues the same one, so its `TtsProgressed` events keep counting
  /// against the original text; Android starts a fresh utterance covering
  /// only the unread remainder, so its events start counting from zero again
  /// — which, measured against the *original* [_totalLength], would read as
  /// the bar jumping backward. Never letting reported progress fall below
  /// its own high-water mark keeps Android honest without `TextToSpeechService`
  /// having to say which kind of resume the engine actually gave it.
  double _peakProgress = 0;

  /// The user's persisted «سرعة القراءة الافتراضية» (F11-T07), for the
  /// options sheet to highlight when it opens on a paper nothing is already
  /// reading — reopening it mid-reading highlights the *current* reading's
  /// own speed instead, which the caller already holds in [state].
  Future<ReadingSpeed> loadDefaultSpeed() => _getDefaultReadingSpeed();

  /// Which reading modes [result] has something to read for, in the order
  /// the options sheet lists them (F30-T19).
  ///
  /// Asked for before the sheet opens rather than being state: nothing about
  /// the player changes by finding out, and the answer belongs to the paper
  /// the caller is holding rather than to whatever is reading now — the same
  /// shape [loadDefaultSpeed] has.
  ///
  /// An empty answer means the paper has nothing readable at all, and the
  /// caller opens no sheet: there would be nothing in it to pick.
  List<ReadingMode> offerableModes({
    required AnalysisResult result,
    required AppStrings strings,
  }) => _offerableReadingModes(result: result, strings: strings);

  /// Whether this device has text-to-speech settings to send the user to
  /// (F30-T07), asked before the way out of [NoArabicVoiceFailure] is
  /// offered.
  Future<bool> canOpenSystemTtsSettings() =>
      _openSystemTtsSettings.isAvailable();

  /// Sends the user to those settings to install a reading voice. Answers
  /// false if nothing could be opened.
  ///
  /// Emits nothing — like [loadDefaultSpeed], this answers its caller rather
  /// than moving the player, since leaving for the settings screen changes
  /// nothing about what is or is not being read.
  Future<bool> openSystemTtsSettings() => _openSystemTtsSettings();

  /// Starts reading [mode] aloud at [speed], replacing whatever was reading
  /// before — `TextToSpeechService.speak` does that on its own, so this never
  /// stops first.
  ///
  /// Reopening the options sheet mid-reading and confirming it again (even on
  /// the same mode) comes back through here too — the sheet is the only place
  /// [speed] changes, so restarting the utterance is how a new speed takes
  /// hold, the same way it is already how a new [mode] does.
  ///
  /// [speed] is applied before speaking starts: `TextToSpeechService`'s own
  /// rate sticks around from whatever it was last set to, so skipping this on
  /// a repeat read would leave the *first* utterance at a stale rate — and, on
  /// the very first read of a fresh cubit, at whatever the shared engine
  /// happened to be left at from something read earlier.
  ///
  /// A failure to apply [speed] is still reported — the same "no silent
  /// failures" reasoning [stop] documents for itself — but does not stop the
  /// read: it starts anyway, at whichever rate the engine already had, rather
  /// than losing the reading entirely over its speed.
  Future<void> start({
    required AnalysisResult result,
    required ReadingMode mode,
    required ReadingSpeed speed,
    required AppStrings strings,
  }) async {
    if (isClosed) return;
    final rateOutcome = await _setReadingSpeed(speed);
    if (isClosed) return;
    if (rateOutcome.failureOrNull case final failure?) {
      emit(AudioReaderFailed(failure));
      if (isClosed) return;
    }
    final outcome = await _startReading(
      result: result,
      mode: mode,
      strings: strings,
    );
    if (isClosed) return;
    emit(
      outcome.when(
        ok: (length) {
          _totalLength = length;
          _peakProgress = 0;
          return AudioReaderReading(mode, speed: speed);
        },
        err: AudioReaderFailed.new,
      ),
    );
  }

  /// Starts reading a plain text string aloud — the raw-text counterpart of
  /// [start], used on the OCR review screen where there is no
  /// [AnalysisResult] yet and the text is read as-is.
  ///
  /// Uses [ReadingMode.extractedText] as the mode label, since that is what
  /// the mini-player displays while the reading is in progress.
  Future<void> startRaw({
    required String text,
    required ReadingSpeed speed,
  }) async {
    if (isClosed) return;
    final rateOutcome = await _setReadingSpeed(speed);
    if (isClosed) return;
    if (rateOutcome.failureOrNull case final failure?) {
      emit(AudioReaderFailed(failure));
      if (isClosed) return;
    }
    final outcome = await _startRawReading(text: text);
    if (isClosed) return;
    emit(
      outcome.when(
        ok: (length) {
          _totalLength = length;
          _peakProgress = 0;
          return AudioReaderReading(ReadingMode.extractedText, speed: speed);
        },
        err: AudioReaderFailed.new,
      ),
    );
  }

  /// Pauses the current reading in place. A no-op if nothing is reading, or
  /// it is already paused — the toggle button that drives this only ever
  /// offers one direction at a time, but a stray second tap should not
  /// re-pause an already-paused engine.
  ///
  /// An engine that refuses the pause keeps reading, so the reading is
  /// stopped before the failure is reported (F30-T14). Reporting alone would
  /// put the player into [AudioReaderFailed], which hides the bar — leaving
  /// the paper being read aloud with no pause and no stop to reach for, and
  /// not even silenced by leaving the page, since [close] only stops a
  /// reading the state still calls one. The user asked for silence; if the
  /// pause cannot give it to them, stopping is closer to the ask than
  /// carrying on talking.
  Future<void> pause() async {
    if (isClosed) return;
    final current = state;
    if (current is! AudioReaderReading || current.isPaused) return;
    final outcome = await _pauseReading();
    if (isClosed) return;
    if (outcome.failureOrNull case final failure?) {
      // The stop's own outcome is not reported over this one: the user asked
      // for a pause, and that is the answer they are owed (the reasoning
      // `ReadingQueue._abandon` follows for the same reason).
      await _stopReading();
      if (isClosed) return;
      _resetProgress();
      emit(AudioReaderFailed(failure));
      return;
    }
    emit(
      AudioReaderReading(
        current.mode,
        isPaused: true,
        speed: current.speed,
        progress: current.progress,
      ),
    );
  }

  /// Resumes a reading previously [pause]d, continuing from where it left
  /// off. A no-op if nothing is paused, the same guard [pause] applies.
  Future<void> resume() async {
    if (isClosed) return;
    final current = state;
    if (current is! AudioReaderReading || !current.isPaused) return;
    final outcome = await _resumeReading();
    if (isClosed) return;
    emit(
      outcome.when(
        ok: (_) => AudioReaderReading(
          current.mode,
          speed: current.speed,
          progress: current.progress,
        ),
        err: AudioReaderFailed.new,
      ),
    );
  }

  /// Stops the current reading. The bar hides either way — there is nothing
  /// more the mini-player itself can offer once the user has asked it to stop
  /// — but a failure to actually silence the engine is still reported rather
  /// than swallowed (no silent failures, CLAUDE.md §A3).
  Future<void> stop() async {
    if (isClosed) return;
    final outcome = await _stopReading();
    if (isClosed) return;
    if (outcome.failureOrNull case final failure?) {
      emit(AudioReaderFailed(failure));
      if (isClosed) return;
    }
    _resetProgress();
    emit(const AudioReaderIdle());
  }

  /// Turns the engine's own playback events into [AudioReaderReading.progress]
  /// (F10-T08); closes the mini-player when a reading finishes on its own —
  /// the same way [stop] closes it when the user asks; and reports an engine
  /// error mid-utterance rather than leaving the bar frozen with no
  /// explanation (no silent failures, CLAUDE.md §A3).
  ///
  /// Pause/resume/cancel events are not handled here: [pause] and [resume]
  /// already emit the right state the moment the user asks for it, and a
  /// cancel the *engine* reports back (rather than one [stop] already
  /// caused) is not something anything in F10 yet triggers on its own.
  void _onEvent(TtsEvent event) {
    if (isClosed) return;
    switch (event) {
      case TtsProgressed(:final end):
        final current = state;
        if (current is! AudioReaderReading) return;
        final total = _totalLength;
        final raw = total == null || total <= 0
            ? 0.0
            : (end / total).clamp(0.0, 1.0).toDouble();
        _peakProgress = raw > _peakProgress ? raw : _peakProgress;
        emit(
          AudioReaderReading(
            current.mode,
            isPaused: current.isPaused,
            speed: current.speed,
            progress: _peakProgress,
          ),
        );
      case TtsCompleted():
        if (state is AudioReaderReading) {
          _resetProgress();
          emit(const AudioReaderIdle());
        }
      case TtsFailed(:final code):
        if (state is AudioReaderReading) {
          _resetProgress();
          // Which sentence the user gets turns on the engine's own code
          // (F30-T08): a condition it named as permanent is not something to
          // ask them to retry, and everything else — including an error it
          // did not explain — keeps the «جرّب تاني» it has always had.
          emit(
            AudioReaderFailed(
              code.isTransient
                  ? TtsFailure(code)
                  : TtsEngineUnavailableFailure(code),
            ),
          );
        }
      case TtsStarted():
      case TtsPaused():
      case TtsContinued():
      case TtsCancelled():
        break;
    }
  }

  /// Clears the per-reading bookkeeping [_onEvent] and [start] otherwise have
  /// to repeat at every place a reading ends, one way or another.
  void _resetProgress() {
    _totalLength = null;
    _peakProgress = 0;
  }

  /// Leaving the result page must not leave the device talking on its own,
  /// and must not leave [_eventsSubscription] listening past this cubit's
  /// own life.
  @override
  Future<void> close() {
    unawaited(_eventsSubscription.cancel());
    if (state is AudioReaderReading) unawaited(_stopReading());
    return super.close();
  }
}
