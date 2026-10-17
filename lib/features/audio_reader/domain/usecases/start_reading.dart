import '../../../../core/documents/analysis_result.dart';
import '../../../../core/documents/reading_mode.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/result/result.dart';
import '../services/reading_queue.dart';
import 'build_reading_text.dart';

/// Starts reading one [ReadingMode] of a result aloud (F10-T04).
///
/// Combines [BuildReadingText] — which turns the mode into the text — with
/// [ReadingQueue.speak], so the mini-player's cubit depends on one use case
/// rather than a builder and a queue directly (architecture rule: cubits
/// depend on use cases only).
///
/// Everything about *how* the text is spoken now lives in the queue
/// (F30-T11): cutting it into one-language runs, picking a voice for each,
/// speaking them in order, and refusing a mostly-Arabic reading on a device
/// with no Arabic voice (F30-T07). This use case is back to what its name
/// says — which mode to read.
///
/// Answers with the spoken text's length on success, in UTF-16 code units —
/// the same unit `TtsProgressed`'s own `start`/`end` are measured in, which
/// the queue now reports in whole-reading coordinates — so the cubit can turn
/// later progress events into a 0-to-1 fraction (F10-T08) without this use
/// case handing back the text itself (kept out of the cubit; nothing about a
/// document's content needs to travel further than it already does to be
/// spoken).
final class StartReading {
  const StartReading(this._buildReadingText, this._queue);

  final BuildReadingText _buildReadingText;
  final ReadingQueue _queue;

  Future<Result<int, AppFailure>> call({
    required AnalysisResult result,
    required ReadingMode mode,
    required AppStrings strings,
  }) {
    final text = _buildReadingText(
      result: result,
      mode: mode,
      strings: strings,
    );
    return _queue.speak(text);
  }
}
