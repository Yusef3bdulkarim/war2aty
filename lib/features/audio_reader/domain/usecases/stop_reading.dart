import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/reading_queue.dart';

/// Stops whatever the reader is speaking (F10-T04).
///
/// A thin forward onto [ReadingQueue.stop] — kept as its own use case rather
/// than a raw call from the cubit, the same architecture rule `StartReading`
/// follows. Also used to silence the engine when the reading cubit is torn
/// down, so leaving the result page never leaves the device talking on its
/// own.
///
/// Goes through the queue rather than straight to the engine since F30-T11:
/// stopping has to drop the runs the reading had not reached yet, or a user
/// who stops in the gap between two of them would be stopping an engine that
/// is not speaking, and the next run would start on its own.
final class StopReading {
  const StopReading(this._queue);

  final ReadingQueue _queue;

  Future<Result<void, AppFailure>> call() => _queue.stop();
}
