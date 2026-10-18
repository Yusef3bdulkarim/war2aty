import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/reading_queue.dart';

/// Pauses the current reading in place, so [ResumeReading] can continue it
/// (F10-T05).
///
/// A thin forward onto [ReadingQueue.pause] — kept as its own use case rather
/// than a raw call from the cubit, the same architecture rule `StopReading`
/// follows.
///
/// Goes through the queue rather than straight to the engine since F30-T11: a
/// reading is several utterances now, and a pause that lands in the gap
/// between two of them pauses an engine that is not speaking. The queue is
/// the only thing that can hold the next run back until the user asks for it
/// again.
final class PauseReading {
  const PauseReading(this._queue);

  final ReadingQueue _queue;

  Future<Result<void, AppFailure>> call() => _queue.pause();
}
