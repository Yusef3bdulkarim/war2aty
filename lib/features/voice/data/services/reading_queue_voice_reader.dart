import 'dart:async';
import 'dart:math' as math;

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../audio_reader/domain/entities/tts_event.dart';
import '../../../audio_reader/domain/services/reading_queue.dart';
import '../../domain/entities/spoken_card_span.dart';
import '../../domain/entities/voice_read_event.dart';
import '../../domain/services/device_voice_reader.dart';
import '../../domain/usecases/build_voice_turn_text.dart';
import '../../domain/usecases/spoken_span_timeline.dart';

/// The fallback tier, over the `flutter_tts` stack F30 and F31 already shipped
/// (F37-T18).
///
/// It **reuses `ReadingQueue` rather than replacing it**, which is what F37's
/// scope fence asked for: voice selection, the mixed-script runs, the
/// transliteration of English on an Arabic-only device, the engine's
/// input-length ceiling and the one silent retry on a passing error are all
/// behaviour the owner's own device drove out over two features, and none of it
/// is worth rewriting to speak a page. The queue also owns the engine — two
/// things speaking into one `flutter_tts` would each take the other's
/// completions for their own — so going around it would break the reading that
/// is already playing.
///
/// What this adds on top is the translation `ReadPaperAloud` needs, and only
/// that:
///
/// * **A read that answers when the reading has ended.** `ReadingQueue.speak`
///   answers once the engine has *taken* the first utterance, which for a page
///   of eight cards is a second into a ninety-second reading. The ladder has to
///   know when the paper has actually been read, so the call is held open until
///   a terminal engine event arrives.
/// * **Character offsets turned into segment ids.** The queue reports progress
///   in offsets into the text it was handed — which is T06's turn text — so
///   [VoiceTurnText.offsets] says directly which segment is being spoken. That
///   is better evidence than the primary tier has: Live has to match a
///   transcription of its own speech, while the device engine says where in the
///   string it is. F40's auto-scroll therefore works on the fallback tier
///   without a single new thing on screen.
/// * **Spans, at the end.** See [_spansFor]: the device engine reports *where*,
///   never *when*, so the timeline is the app's own clock, and its total is not
///   known until the reading stops.
///
/// **It never announces itself.** [VoiceReadStarted], [VoiceReadCompleted] and
/// [VoiceReadFailed] belong to `ReadPaperAloud`, the only thing that knows this
/// is the last tier — see [DeviceVoiceReader].
///
/// **Privacy.** The page's text passes straight through to the engine and is
/// never logged, and no event this emits carries a word of it (CLAUDE.md §7).
final class ReadingQueueVoiceReader implements DeviceVoiceReader {
  ReadingQueueVoiceReader(this._queue, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    // Subscribed for as long as this object lives, the same as the queue's own
    // subscription to the engine and for the same reason: a completion that
    // arrives before anyone is listening is a reading that never ends. Events
    // belonging to anything else that speaks — the Settings voice preview, the
    // old result screen's reader — land here with no reading of ours in flight
    // and are ignored.
    _queue.events.listen(_onReadingEvent);
  }

  final ReadingQueue _queue;
  final DateTime Function() _now;

  /// Broadcast, because `ReadPaperAloud` subscribes afresh for every read while
  /// this object lives for the app's lifetime, and **synchronous**, because the
  /// spans are emitted in the same turn the read is answered in: the ladder
  /// cancels its subscription the moment [read] answers, so an asynchronously
  /// delivered span event could arrive after nobody was listening.
  final _events = StreamController<VoiceReadEvent>.broadcast(sync: true);

  /// The reading in flight, or `null` between readings.
  _Reading? _reading;

  @override
  Stream<VoiceReadEvent> get events => _events.stream;

  @override
  Future<Result<Duration, AppFailure>> read(VoiceTurnText turn) async {
    final reading = _Reading(turn: turn, issuedAt: _now());
    // A second read supersedes the first, the way `ReadingQueue.speak` does:
    // the superseded one is never going to be finished by the engine, and a
    // caller left waiting on it would wait forever.
    _reading?.finish(const Err(TtsFailure()));
    _reading = reading;

    final accepted = await _queue.speak(turn.text);
    if (accepted.failureOrNull case final failure?) {
      // Reported as the queue reported it — a [NoArabicVoiceFailure] arrives at
      // the ladder intact so the screen can offer the system TTS settings
      // (F30-T07).
      if (identical(_reading, reading)) _reading = null;
      reading.finish(Err(failure));
      return Err(failure);
    }

    return reading.outcome;
  }

  @override
  Future<void> stop() async {
    final reading = _reading;
    // Nothing of ours is speaking, so there is nothing of ours to silence —
    // and the engine is shared. `ReadPaperAloud` calls this on every cancel,
    // including one where Live was the tier that read, so stopping the queue
    // here regardless would silence whatever else was using it.
    if (reading == null) return;
    _reading = null;
    // A deliberate stop is not a failure: the reading lasted what it lasted,
    // and the caller that asked for it is the one tearing it down.
    reading.finish(Ok(_elapsedOf(reading)));
    await _queue.stop();
  }

  /// Turns the reading's own events into F37's (see [events]).
  void _onReadingEvent(TtsEvent event) {
    final reading = _reading;
    if (reading == null) return;

    switch (event) {
      // Both mean the same thing here: the reading is now being spoken.
      // Android reports a continue rather than a start for the first utterance
      // after a pause, including a reading begun while the engine was left
      // paused.
      case TtsStarted():
      case TtsContinued():
        if (reading.started) return;
        reading.start(_now());
        _emitPosition(reading, Duration.zero, 0);

      case TtsProgressed(:final start):
        if (!reading.started) return;
        final at = _elapsedOf(reading);
        reading.heard(start, at);
        _emitPosition(reading, at, start);

      case TtsCompleted():
        final duration = _elapsedOf(reading);
        _reading = null;
        // Emitted before the read is answered, and synchronously, so the
        // ladder still has its subscription when they arrive.
        _events.add(VoiceReadSpansResolved(_spansFor(reading, duration)));
        reading.finish(Ok(duration));

      case TtsFailed():
        // Only a failure the queue did not absorb reaches here: a passing one
        // has already been retried in silence (F30-T16). Reported as the same
        // [TtsFailure] the rest of this stack answers a refused reading with —
        // the engine's own code is the queue's business, not the ladder's.
        _reading = null;
        reading.finish(const Err(TtsFailure()));

      case TtsCancelled():
        // A cancel is not only what a stop produces: the engine reports one for
        // the utterance a newly started reading just flushed, and that one
        // arrives *after* this reading was installed. Acting on it would fail a
        // reading that is about to be spoken perfectly well. A cancel that
        // interrupts a reading the engine had told us was speaking is the other
        // kind — something outside the queue took the engine — and the paper is
        // not going to be finished. Our own [stop] clears [_reading] before it
        // asks, so the cancel it produces never reaches here.
        if (!reading.started) return;
        _reading = null;
        reading.finish(const Err(TtsFailure()));

      case TtsPaused():
        // This tier never pauses: the ladder reads a paper from end to end or
        // stops it. A pause from somewhere else is not this reading's to act
        // on.
        break;
    }
  }

  void _emitPosition(_Reading reading, Duration at, int charOffset) {
    _events.add(
      VoiceReadPositionChanged(
        position: at,
        segmentId: reading.segmentAt(charOffset),
      ),
    );
  }

  Duration _elapsedOf(_Reading reading) {
    final elapsed = _now().difference(reading.startedAt ?? reading.issuedAt);
    // A clock that went backwards — the user changed the time mid-reading — is
    // not worth a negative position.
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Where each segment was spoken, on the clock this read was measured with.
  ///
  /// The evidence is every word boundary the engine reported: each is a point
  /// where a known character offset was known to be reaching the speaker. Those
  /// points, plus the start and the end of the reading, are the timeline;
  /// everything between them is interpolated, which is exactly what the primary
  /// tier does with the points its transcription gives it.
  ///
  /// A segment is [SpokenCardSpan.exact] when a word boundary actually landed
  /// inside it. One that none did — a card of two words the engine stepped
  /// over, or every card on an engine that reports no boundaries at all — is
  /// placed by its share of the characters between the boundaries around it,
  /// and says so. With no boundaries anywhere that reduces to each segment's
  /// share of the whole reading, which is the honest floor.
  ///
  /// Measured against the **turn text**, separators included, deliberately
  /// unlike `AlignSegmentsToAudio`: the engine is speaking the turn text, and
  /// the pause T06's separator produces is time this reading actually spends.
  List<SpokenCardSpan> _spansFor(_Reading reading, Duration duration) {
    final offsets = reading.turn.offsets;
    if (offsets.isEmpty) return const [];

    final totalMicros = duration.inMicroseconds;
    final totalChars = reading.turn.text.length;

    // The reading starts at the start of the clock: a real observation, and the
    // left-hand end of every interpolation.
    final chars = <int>[0];
    final micros = <int>[0];
    for (final boundary in reading.boundaries) {
      // A boundary that does not advance the character count carries nothing,
      // and one past the end of the text is not describing this reading.
      if (boundary.charOffset <= chars.last) continue;
      if (boundary.charOffset >= totalChars) continue;
      chars.add(boundary.charOffset);
      micros.add(
        math.min(
          math.max(boundary.at.inMicroseconds, micros.last),
          totalMicros,
        ),
      );
    }
    if (totalChars > chars.last) {
      chars.add(totalChars);
      micros.add(math.max(micros.last, totalMicros));
    }

    return partitionSpans(
      segmentIds: [for (final offset in offsets) offset.segmentId],
      startMicros: [
        for (final offset in offsets)
          interpolateAt(chars, micros, offset.start),
      ],
      exact: [for (final offset in offsets) reading.wasHeardIn(offset)],
      totalMicros: totalMicros,
    );
  }
}

/// One reading in flight: what is being spoken, when it started, and every word
/// boundary the engine has reported so far.
final class _Reading {
  _Reading({required this.turn, required this.issuedAt});

  final VoiceTurnText turn;

  /// When [ReadingQueueVoiceReader.read] was called — the fallback start for an
  /// engine that completes a reading without ever saying it began.
  final DateTime issuedAt;

  DateTime? startedAt;
  bool get started => startedAt != null;

  final List<_Boundary> boundaries = [];

  final _completer = Completer<Result<Duration, AppFailure>>();
  Future<Result<Duration, AppFailure>> get outcome => _completer.future;

  void start(DateTime at) => startedAt = at;

  void heard(int charOffset, Duration at) =>
      boundaries.add(_Boundary(charOffset: charOffset, at: at));

  /// Which segment [charOffset] falls in, or `null` in the separator between
  /// two of them — where [VoiceReadPositionChanged] asks the screen to hold the
  /// highlight it has rather than clear it.
  String? segmentAt(int charOffset) {
    for (final offset in turn.offsets) {
      if (charOffset >= offset.start && charOffset < offset.end) {
        return offset.segmentId;
      }
    }
    return null;
  }

  /// Whether the engine reported a word boundary inside [offset] — the
  /// difference between a measured span and an interpolated one.
  bool wasHeardIn(SegmentCharOffset offset) => boundaries.any(
    (boundary) =>
        boundary.charOffset >= offset.start && boundary.charOffset < offset.end,
  );

  /// Answers the read, once. Every later terminal event is a reading that was
  /// already decided — a cancel arriving after a completion, say.
  void finish(Result<Duration, AppFailure> outcome) {
    if (_completer.isCompleted) return;
    _completer.complete(outcome);
  }
}

/// A word boundary: where the engine said it had reached, and when.
final class _Boundary {
  const _Boundary({required this.charOffset, required this.at});

  /// An offset into the turn text, in UTF-16 code units. Never the text itself:
  /// these are the paper's own words (CLAUDE.md §7).
  final int charOffset;

  final Duration at;
}
