import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/reading_queue.dart';
import 'normalize_spoken_numbers.dart';

/// Starts reading a plain text string aloud — the raw-text counterpart of
/// [StartReading], used on the OCR review screen where there is no
/// [AnalysisResult] yet and [BuildReadingText] has nothing to build from.
///
/// Applies [normalizeSpokenNumbers] so phone numbers, dates, and amounts are
/// spoken the same way they would be in a full analysis reading, then hands
/// the result to [ReadingQueue.speak] — which cuts it into one-language runs
/// and speaks them in order (F30-T11), the same path a full reading takes.
///
/// Answers with the spoken text's length in UTF-16 code units, the same
/// contract [StartReading] follows, so [AudioReaderCubit] can turn later
/// `TtsProgressed` events into a 0-to-1 fraction without this use case
/// handing back the text itself.
final class StartRawReading {
  const StartRawReading(this._queue);

  final ReadingQueue _queue;

  Future<Result<int, AppFailure>> call({required String text}) async {
    final normalized = normalizeSpokenNumbers(text).trim();
    // The queue refuses an empty reading too, but an OCR review screen with
    // nothing on it is the one place a caller can realistically ask for one,
    // so it is named here rather than left to be inferred.
    if (normalized.isEmpty) return const Err(TtsFailure());
    return _queue.speak(normalized);
  }
}
