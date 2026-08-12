import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/audio_reader/domain/entities/reading_speed.dart';
import '../../features/audio_reader/domain/entities/tts_event.dart';
import '../../features/audio_reader/domain/usecases/pause_reading.dart';
import '../../features/audio_reader/domain/usecases/resume_reading.dart';
import '../../features/audio_reader/domain/usecases/set_reading_speed.dart';
import '../../features/audio_reader/domain/usecases/start_reading.dart';
import '../../features/audio_reader/domain/usecases/stop_reading.dart';
import '../../features/audio_reader/domain/usecases/watch_reading_events.dart';
import '../documents/analysis_result.dart';
import '../documents/reading_mode.dart';
import '../error/app_failure.dart';
import '../localization/app_strings.dart';
import 'audio_reader_state.dart';

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
    this._stopReading,
    this._pauseReading,
    this._resumeReading,
    this._setReadingSpeed,
    this._watchReadingEvents,
  ) : super(const AudioReaderIdle()) {
    _eventsSubscription = _watchReadingEvents().listen(_onEvent);
  }

  final StartReading _startReading;
  final StopReading _stopReading;
  final PauseReading _pauseReading;
  final ResumeReading _resumeReading;
  final SetReadingSpeed _setReadingSpeed;
  final WatchReadingEvents _watchReadingEvents;

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

  /// Pauses the current reading in place. A no-op if nothing is reading, or
  /// it is already paused — the toggle button that drives this only ever
  /// offers one direction at a time, but a stray second tap should not
  /// re-pause an already-paused engine.
  Future<void> pause() async {
    if (isClosed) return;
    final current = state;
    if (current is! AudioReaderReading || current.isPaused) return;
    final outcome = await _pauseReading();
    if (isClosed) return;
    emit(
      outcome.when(
        ok: (_) => AudioReaderReading(
          current.mode,
          isPaused: true,
          speed: current.speed,
          progress: current.progress,
        ),
        err: AudioReaderFailed.new,
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
      case TtsFailed():
        if (state is AudioReaderReading) {
          _resetProgress();
          emit(const AudioReaderFailed(TtsFailure()));
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
