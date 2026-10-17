import 'dart:async';

import '../../../../core/audio/tts_voice.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/language_run.dart';
import '../entities/tts_event.dart';
import '../usecases/segment_language_runs.dart';
import '../usecases/select_voice_for_reading.dart';
import 'text_to_speech_service.dart';

/// Speaks a reading as a queue of one-language utterances, one after the
/// other (F30-T11).
///
/// The second half of the fix for RC-4. `SegmentLanguageRuns` cuts the
/// reading into runs of a single language; this hands them to the engine one
/// at a time, each with a voice that can pronounce it, and moves to the next
/// when the engine says the current one finished. Before it, an Arabic paper
/// with English words in it was one utterance in one voice, and whichever
/// script lost got named character by character.
///
/// **Everything that speaks goes through here.** The queue is what the
/// engine's events are read against, so a `speak` issued behind its back
/// would have its completion taken for the end of a run and advance someone
/// else's reading. The one exception is the voice preview in Settings
/// (`PreviewDefaultVoice`), which previews a specific voice rather than
/// reading a paper — see [_onEngineEvent]'s cancel case for what keeps that
/// honest.
///
/// Driven by completion events rather than `QUEUE_ADD` (F30 locked decision
/// 6): whether Android captures a per-utterance voice at queue time is
/// engine-dependent and was not going to be assumed from documentation. The
/// accepted cost is a small gap between runs — the engine releases audio
/// focus at the end of each utterance and requests it again for the next.
/// F30-T12 spikes `QUEUE_ADD` on a real device and adopts it only if the
/// voice is honoured per utterance.
///
/// Stateful, and therefore the one thing in this layer that is not a
/// value or a pure function: it is registered as a lazy singleton because
/// the engine it drives is itself a single shared resource, and two queues
/// over one engine would each take the other's completions for their own.
/// It holds no platform dependency — only [TextToSpeechService], the same
/// interface every other use case here depends on — so the domain layer
/// stays free of plugins.
final class ReadingQueue {
  ReadingQueue(this._tts, this._segment, this._selectVoice) {
    // Subscribed for as long as this object lives, which is as long as the
    // engine does — both are app-lifetime singletons, and the engine's own
    // event controller is never closed either, so there is no point at which
    // this subscription should end. It is deliberately started here rather
    // than on the first reading: a completion that arrives before anyone
    // subscribed is a run that never gets its successor.
    _tts.events.listen(_onEngineEvent);
  }

  final TextToSpeechService _tts;
  final SegmentLanguageRuns _segment;
  final SelectVoiceForReading _selectVoice;

  final _readingEvents = StreamController<TtsEvent>.broadcast();

  /// The reading currently installed, in the order it will be spoken.
  ///
  /// Empty between readings. [_index] is the one the engine is on.
  List<_Utterance> _utterances = const [];
  int _index = 0;

  /// Where the utterance now speaking begins in the whole reading, in UTF-16
  /// code units — what turns the engine's per-utterance progress offsets
  /// into offsets into the reading. Held as a field rather than read off
  /// [_utterances] so an event arriving after the queue was cleared cannot
  /// index an empty list.
  int _offset = 0;

  /// Whether the engine has reported that the utterance last handed to it
  /// began. See [_onEngineEvent]'s cancel case, which is the only thing that
  /// reads it.
  bool _currentStarted = false;

  /// Bumped every time a caller claims the engine — by [speak] and by
  /// [stop]. An asynchronous step that was already in flight when that
  /// happened compares against the value it captured and stands down, so a
  /// reading the user has moved on from cannot speak its next run over the
  /// one they asked for instead (the same rule `OcrReviewCubit` follows for
  /// answers to requests the user left behind, F20 §4).
  int _generation = 0;

  /// The reading's lifecycle, rather than the engine's (F30-T11).
  ///
  /// Two differences from [TextToSpeechService.events], both of which exist
  /// so a consumer can keep treating one reading as one thing:
  ///
  /// * A run finishing mid-reading is swallowed. Only the last one's
  ///   completion is a [TtsCompleted], because only that one means the
  ///   reading is over — the mini-player closes on it (F10-T08).
  /// * [TtsProgressed]'s offsets are moved into the whole reading's
  ///   coordinates. The engine counts them from the start of the utterance
  ///   it is speaking; a consumer measuring progress against the length of
  ///   the *reading* would otherwise see the fraction restart at every run.
  Stream<TtsEvent> get events => _readingEvents.stream;

  /// Speaks [text], replacing whatever was reading before.
  ///
  /// Answers once the **first** utterance has been accepted — not when the
  /// reading ends — so a caller still learns, before it shows a player, that
  /// the engine took the reading (F30-T09). The rest of the queue follows on
  /// its own; a later run that the engine refuses is reported as a
  /// [TtsFailed] on [events], since by then there is no call left to answer.
  ///
  /// Answers with [text]'s own length in UTF-16 code units, the unit
  /// [events]' progress offsets are now measured in.
  ///
  /// Failures:
  /// - [NoArabicVoiceFailure] — the reading is mostly Arabic and the device
  ///   has no Arabic voice at all (F30-T07). Decided on the whole reading
  ///   rather than per run on purpose: a mostly-English paper with one
  ///   Arabic word in it still reads usefully in an English voice, and
  ///   refusing it outright over that one word would be worse than mangling
  ///   it. What RC-1 is about is the other case — a mostly-Arabic paper
  ///   handed to an English voice produces nothing audible at all.
  /// - [TtsFailure] — there was nothing to speak, or the engine would not
  ///   take the first utterance.
  Future<Result<int, AppFailure>> speak(String text) async {
    // An empty utterance behaves differently on every engine, so it is never
    // sent (F30 "Secondary"). F30-T19 is what stops a mode with no content
    // being offered in the first place.
    if (text.trim().isEmpty) return const Err(TtsFailure());

    final generation = ++_generation;
    final runs = _segment(text);
    // Cached since F30-T04, so this is not the round trip per reading it
    // used to be (F30 RC-6).
    final voices = (await _tts.getVoices()).valueOrNull ?? const <TtsVoice>[];
    if (_noVoiceForAnArabicReading(text, voices)) {
      return const Err(NoArabicVoiceFailure());
    }
    // Somebody else claimed the engine while the voices were being fetched.
    // Not a failure to report: their reading is the one the user asked for,
    // and theirs is the answer that counts.
    if (_generation != generation) return Ok(text.length);

    _utterances = _queueFor(runs, voices);
    _index = 0;
    final outcome = await _handOver(_utterances.first, generation);
    return outcome.map((_) => text.length);
  }

  /// Stops the reading and drops the runs it had not reached yet.
  ///
  /// Clearing before the engine is asked to stop, and not after, is the
  /// point: a user who stops in the gap between two runs has stopped
  /// something the engine is not currently speaking, so there would be
  /// nothing for [TextToSpeechService.stop] to silence — and the next run
  /// would start talking into an empty screen.
  Future<Result<void, AppFailure>> stop() {
    _generation++;
    _clear();
    return _tts.stop();
  }

  /// Hands one utterance to the engine, after switching to its voice.
  ///
  /// The voice switch is best-effort, the same as it has been since F10-T07:
  /// a `setVoice` that fails leaves the engine on whatever voice it had, and
  /// that is not worth losing a reading over.
  Future<Result<void, AppFailure>> _handOver(
    _Utterance utterance,
    int generation,
  ) async {
    _currentStarted = false;
    _offset = utterance.offset;
    if (utterance.voice case final voice?) await _tts.setVoice(voice);
    // Checked after the voice switch and before speaking, so a [stop] that
    // lands in the middle of it does not get a run spoken over it.
    if (_generation != generation) return const Ok(null);
    return _tts.speak(utterance.text);
  }

  /// Speaks the run after the one that just finished.
  ///
  /// Nothing awaits this — the engine's completion event is what triggered
  /// it — so a failure here has no call to answer and is published on
  /// [events] instead. It reads as retryable: a run the engine would not
  /// take is the same kind of refusal a first run's would have been, and
  /// «جرّب تاني» is the right offer.
  Future<void> _advanceTo(_Utterance utterance, int generation) async {
    final outcome = await _handOver(utterance, generation);
    if (_generation != generation) return;
    if (outcome.failureOrNull != null) {
      _clear();
      _readingEvents.add(const TtsFailed());
    }
  }

  /// Turns the engine's own events into the reading's (see [events]), and
  /// moves the queue along.
  void _onEngineEvent(TtsEvent event) {
    switch (event) {
      case TtsStarted():
        _currentStarted = true;
        // The reading starts when its first run does; the others start
        // nothing the consumer did not already know about.
        if (_index == 0) _readingEvents.add(event);

      case TtsProgressed(:final start, :final end):
        _readingEvents.add(
          TtsProgressed(start: _offset + start, end: _offset + end),
        );

      case TtsCompleted():
        final next = _index + 1;
        if (next < _utterances.length) {
          _index = next;
          // Read out of the list here, while it is known to be in range,
          // rather than inside the asynchronous step below.
          unawaited(_advanceTo(_utterances[next], _generation));
          return;
        }
        _clear();
        _readingEvents.add(event);

      case TtsFailed():
        // The reading is over however many runs were left: the engine has
        // stopped, and nothing will complete to carry the queue forward.
        _clear();
        _readingEvents.add(event);

      case TtsCancelled():
        // A cancel is not only what a [stop] produces. The engine reports
        // one for the utterance a *newly* started reading just flushed, and
        // that one arrives after the new reading is already installed — so
        // clearing on every cancel would throw away the queue of the
        // reading the user just asked for. A cancel that interrupts a run
        // the engine had told us began is the other kind: something outside
        // this queue took the engine (the Settings voice preview is the one
        // thing that can), and the runs behind it are not going to be read.
        if (_currentStarted) _clear();
        _readingEvents.add(event);

      case TtsPaused():
      case TtsContinued():
        _readingEvents.add(event);
    }
  }

  /// One utterance per run, each knowing where it starts in the reading and
  /// which voice reads it.
  ///
  /// A run whose language the device has no voice for keeps `null` and is
  /// read in whatever voice the engine already had — today that means an
  /// English run on a device with no English voice is still named
  /// letter-by-letter, which is exactly what F30-T17's transliteration
  /// fallback is for. Dropping the run instead would be worse: it would read
  /// the paper with a piece of it missing and say nothing about it.
  List<_Utterance> _queueFor(List<LanguageRun> runs, List<TtsVoice> voices) {
    final utterances = <_Utterance>[];
    var offset = 0;
    for (final run in runs) {
      utterances.add(
        _Utterance(
          text: run.text,
          offset: offset,
          voice: voices.isEmpty
              ? null
              : _selectVoice.forLanguage(run.language, voices),
        ),
      );
      offset += run.text.length;
    }
    return utterances;
  }

  /// Whether this reading cannot usefully be spoken at all for want of an
  /// Arabic voice (F30-T07, RC-1).
  ///
  /// An engine that answered with no voices at all is not evidence of
  /// anything — Android reports an empty list while it is still binding — so
  /// it reads on rather than accusing the device of lacking a voice.
  bool _noVoiceForAnArabicReading(String text, List<TtsVoice> voices) =>
      voices.isNotEmpty &&
      _selectVoice.languageFor(text) == ReadingLanguage.arabic &&
      _selectVoice(text, voices) == null;

  /// Forgets the installed reading. Does **not** touch [_generation]: a
  /// [speak] that is mid-flight has already claimed it, and invalidating it
  /// here would stand that reading down before it ever spoke.
  void _clear() {
    _utterances = const [];
    _index = 0;
    _offset = 0;
    _currentStarted = false;
  }
}

/// One queued utterance: a slice of the reading, where it starts, and the
/// voice to read it with.
final class _Utterance {
  const _Utterance({
    required this.text,
    required this.offset,
    required this.voice,
  });

  final String text;

  /// Where [text] begins in the whole reading, in UTF-16 code units.
  final int offset;

  /// `null` to read it with whatever voice the engine already has — see
  /// [ReadingQueue._queueFor].
  final TtsVoice? voice;
}
