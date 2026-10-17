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

  /// An empty reading is the queue's to refuse — the OCR review screen can
  /// ask for one when the page came back blank, and the queue answers the
  /// same `TtsFailure` whether the emptiness arrived from here or from a
  /// reading mode with no content. Checking it here as well would be a second
  /// path to the same answer, and the one that skipped the queue would leave
  /// a previous reading talking (F30-T11).
  Future<Result<int, AppFailure>> call({required String text}) =>
      _queue.speak(normalizeSpokenNumbers(text).trim());
}
