import '../entities/tts_event.dart';
import '../services/reading_queue.dart';

/// The reader's playback lifecycle, one [TtsEvent] per state change (F10-T08).
///
/// A thin forward onto [ReadingQueue.events] — kept as its own use case
/// rather than a raw stream read from the cubit, the same architecture rule
/// `PauseReading` and its siblings follow.
///
/// The queue's stream and not the engine's, since F30-T11: a reading is now
/// several utterances, and a consumer of this wants the *reading's*
/// lifecycle. The queue is what swallows a run finishing mid-reading and
/// what puts progress offsets back into the whole reading's coordinates —
/// see [ReadingQueue.events].
final class WatchReadingEvents {
  const WatchReadingEvents(this._queue);

  final ReadingQueue _queue;

  Stream<TtsEvent> call() => _queue.events;
}
