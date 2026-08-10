import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/audio_reader/domain/usecases/start_reading.dart';
import '../../features/audio_reader/domain/usecases/stop_reading.dart';
import '../documents/analysis_result.dart';
import '../documents/reading_mode.dart';
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
  AudioReaderCubit(this._startReading, this._stopReading)
    : super(const AudioReaderIdle());

  final StartReading _startReading;
  final StopReading _stopReading;

  /// Starts reading [mode] aloud, replacing whatever was reading before —
  /// `TextToSpeechService.speak` does that on its own, so this never stops
  /// first.
  Future<void> start({
    required AnalysisResult result,
    required ReadingMode mode,
    required AppStrings strings,
  }) async {
    if (isClosed) return;
    final outcome = await _startReading(
      result: result,
      mode: mode,
      strings: strings,
    );
    if (isClosed) return;
    emit(
      outcome.when(
        ok: (_) => AudioReaderReading(mode),
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
    emit(const AudioReaderIdle());
  }

  /// Leaving the result page must not leave the device talking on its own.
  @override
  Future<void> close() {
    if (state is AudioReaderReading) unawaited(_stopReading());
    return super.close();
  }
}
