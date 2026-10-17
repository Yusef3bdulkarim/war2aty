import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/reading_queue.dart';

/// Resumes a reading previously paused, continuing from where it left off
/// (F10-T05).
///
/// A thin forward onto [ReadingQueue.resume] — kept as its own use case
/// rather than a raw call from the cubit, the same architecture rule
/// `StopReading` follows.
///
/// Goes through the queue since F30-T11, for the reason [PauseReading]
/// documents: when the pause landed between two runs there is nothing for the
/// engine to continue, and resuming means speaking the run that was held
/// back.
final class ResumeReading {
  const ResumeReading(this._queue);

  final ReadingQueue _queue;

  Future<Result<void, AppFailure>> call() => _queue.resume();
}
