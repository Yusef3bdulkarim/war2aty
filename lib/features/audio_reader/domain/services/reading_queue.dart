import 'dart:async';

import '../../../../core/audio/tts_error_code.dart';
import '../../../../core/audio/tts_voice.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/language_run.dart';
import '../entities/tts_event.dart';
import '../usecases/chunk_text_for_speaking.dart';
import '../usecases/segment_language_runs.dart';
import '../usecases/select_voice_for_reading.dart';
import '../usecases/transliterate_latin_to_arabic.dart';
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
/// An English run on a device that has an Arabic voice and no English one is
/// written in Arabic letters before it is queued (F30-T17), and read by the
/// Arabic voice: «إنفويس» rather than `invoice` named one character at a
/// time. What such an item covers of the reading is then no longer the
/// length of what it says, which is why [_Utterance] carries both.
///
/// A run the engine would refuse for its length is cut into several queue
/// items first (F30-T15), so what is queued is "a piece of the reading in one
/// language, short enough to speak" rather than strictly one run. Nothing
/// else in here distinguishes the two: a cut run advances, pauses, resumes
/// and reports progress exactly as an uncut one does. The cost is the gap
/// between two pieces of the same run, which is the same gap a language
/// switch pays and is paid only by a run over 4000 characters.
///
/// An item the engine fails on for a reason the engine itself called a
/// passing one is spoken again, once, in silence (F30-T16) — see
/// [_shouldRetry]. That is the half of RC-2 the user feels: before it, a
/// voice whose data was still downloading and a network voice that could not
/// reach its audio both closed the player and asked the user to tap again.
///
/// **Everything that plays goes through here** — speaking, pausing, resuming
/// and stopping. The queue is what the engine's events are read against, so a
/// `speak` issued behind its back would have its completion taken for the end
/// of a run and advance someone else's reading, and a `pause` issued behind
/// its back would be a player that says paused while the next run talks over
/// it. The one exception is the voice preview in Settings
/// (`PreviewDefaultVoice`), which previews a specific voice rather than
/// reading a paper — see [_onEngineEvent]'s cancel case for what keeps that
/// honest.
///
/// Two invariants hold across every path in here, and the tests assert both:
///
/// * **Either the reading is installed and playing, or nothing is installed
///   and the engine is silent.** A [speak] that fails never leaves the
///   previous reading talking on under a screen that is about to show a
///   failure.
/// * **Nothing is spoken while the player is paused.** A run that comes due
///   during a pause is parked, and [resume] is what lets it go.
///
/// Driven by completion events rather than `QUEUE_ADD`, which F30-T12
/// settled on a device. Its premise turned out to be wrong: the voice *is*
/// captured per utterance — by the framework, above any engine — so
/// `QUEUE_ADD` would have read every run in its own voice and closed the gap
/// between them entirely. It is still not used, because `flutter_tts`'s
/// pause is `TextToSpeech.stop()`: one pause discards every run still
/// queued, and resumes near the end of the run that was speaking rather than
/// where it was heard to stop — both of the invariants above, broken at
/// once. The accepted cost is that gap, measured at 0.4–1.5s per language
/// switch, most of which is the awaited `setVoice` in [_handOver] rather
/// than the engine's own start-up.
///
/// Stateful, and therefore the one thing in this layer that is not a value or
/// a pure function: it is registered as a lazy singleton because the engine
/// it drives is itself a single shared resource, and two queues over one
/// engine would each take the other's completions for their own. It holds no
/// platform dependency — only [TextToSpeechService], the same interface every
/// other use case here depends on — so the domain layer stays free of
/// plugins.
final class ReadingQueue {
  ReadingQueue(
    this._tts,
    this._segment,
    this._selectVoice,
    this._chunk,
    this._transliterate,
  ) {
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
  final ChunkTextForSpeaking _chunk;
  final TransliterateLatinToArabic _transliterate;

  final _readingEvents = StreamController<TtsEvent>.broadcast();

  /// The reading currently installed, in the order it will be spoken.
  ///
  /// Empty between readings. [_index] is the one the engine is on.
  List<_Utterance> _utterances = const [];
  int _index = 0;

  /// The utterance now speaking — what turns the engine's per-utterance
  /// progress offsets into offsets into the reading, through
  /// [_Utterance.readingOffsetFor]. Held as a field rather than read off
  /// [_utterances] so an event arriving after the queue was cleared cannot
  /// index an empty list.
  _Utterance? _speaking;

  /// Whether the engine has reported that the utterance last handed to it is
  /// speaking. See [_onEngineEvent]'s cancel case, which is the only thing
  /// that reads it.
  bool _currentStarted = false;

  /// Whether the player is paused. Nothing is handed to the engine while this
  /// is set — see [_parked].
  bool _paused = false;

  /// The run that came due while the player was paused, waiting for
  /// [resume].
  ///
  /// This is the gap the queue created and that nothing else could close: a
  /// pause that lands *between* two runs pauses an engine that is not
  /// speaking, so the engine has nothing to continue later and reports
  /// nothing now. Without parking the next run, the player would either talk
  /// under a paused bar or never speak again.
  _Utterance? _parked;

  /// Whether the utterance the queue is on has already been spoken a second
  /// time after a transient engine error (F30-T16).
  ///
  /// One retry per queue item, not per reading: a long paper is many items,
  /// and a network voice that drops one of them may well drop another later
  /// without either being a reading the user should be made to restart.
  /// Cleared when the queue moves on to the next item, and by [_clear].
  bool _retriedCurrent = false;

  /// Whether a hand-over is in flight — between choosing an utterance and the
  /// engine accepting it.
  ///
  /// Nothing of this queue's is speaking during that window, so a completion
  /// arriving in it belongs to something else: the reading a [speak] is in
  /// the middle of replacing, or an engine reporting one utterance twice.
  /// Acting on it would advance the queue by two and skip a run.
  bool _handingOver = false;

  /// Bumped every time a caller claims the engine — by [speak] and by [stop].
  /// An asynchronous step that was already in flight when that happened
  /// compares against the value it captured and stands down, so a reading the
  /// user has moved on from cannot speak its next run over the one they asked
  /// for instead (the same rule `OcrReviewCubit` follows for answers to
  /// requests the user left behind, F20 §4).
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
  ///   coordinates. The engine counts them from the start of the utterance it
  ///   is speaking; a consumer measuring progress against the length of the
  ///   *reading* would otherwise see the fraction restart at every run.
  Stream<TtsEvent> get events => _readingEvents.stream;

  /// Speaks [text], replacing whatever was reading before.
  ///
  /// Answers once the **first** utterance has been accepted — not when the
  /// reading ends — so a caller still learns, before it shows a player, that
  /// the engine took the reading (F30-T09). The rest of the queue follows on
  /// its own; a later run that the engine refuses is reported as a
  /// [TtsFailed] on [events], since by then there is no call left to answer.
  ///
  /// Answers with [text]'s own length in UTF-16 code units, the unit [events]'
  /// progress offsets are now measured in.
  ///
  /// Every failure here leaves the engine silent and nothing installed, and
  /// that is the point of [_abandon]: the caller is about to replace a player
  /// with an error, and a reading the user has already been told has failed
  /// must not still be talking behind it.
  ///
  /// Failures:
  /// - [NoArabicVoiceFailure] — the reading is mostly Arabic and the device
  ///   has no Arabic voice at all (F30-T07). Decided on the whole reading
  ///   rather than per run on purpose: a mostly-English paper with one Arabic
  ///   word in it still reads usefully in an English voice, and refusing it
  ///   outright over that one word would be worse than mangling it. What RC-1
  ///   is about is the other case — a mostly-Arabic paper handed to an English
  ///   voice produces nothing audible at all.
  /// - [TtsFailure] — there was nothing to speak, or the engine would not take
  ///   the first utterance.
  Future<Result<int, AppFailure>> speak(String text) async {
    // Claimed before the first check, not after: every path below ends either
    // with this reading installed or with nothing installed, and a run of the
    // previous reading that is mid-hand-over has to stand down either way.
    final generation = ++_generation;

    // An empty utterance behaves differently on every engine, so it is never
    // sent (F30 "Secondary"). F30-T19 is what stops a mode with no content
    // being offered in the first place.
    if (text.trim().isEmpty) return Err(await _abandon(const TtsFailure()));

    final runs = _segment(text);
    // Both cached after the first reading of the session — the voices since
    // F30-T04, the limit since F30-T15 — and asked for together rather than
    // one after the other, so a cold start pays for the slower of the two
    // instead of for both (F30 RC-6).
    final askedForVoices = _tts.getVoices();
    final askedForLimit = _tts.getMaxInputLength();
    final voices = (await askedForVoices).valueOrNull ?? const <TtsVoice>[];
    final limit = await askedForLimit;
    if (_generation != generation) return Ok(text.length);
    if (_noVoiceForAnArabicReading(text, voices)) {
      return Err(await _abandon(const NoArabicVoiceFailure()));
    }

    _install(_queueFor(runs, voices, limit));
    final outcome = await _handOver(_utterances.first, generation);
    // Somebody else claimed the engine while this was being handed over. Not
    // ours to report on and not ours to silence: their reading is the one the
    // user asked for.
    if (_generation != generation) return Ok(text.length);
    if (outcome.failureOrNull case final failure?) {
      return Err(await _abandon(failure));
    }
    return Ok(text.length);
  }

  /// Pauses the reading where it is, including between two runs.
  ///
  /// Sets the flag before asking the engine, so a run that comes due while
  /// the pause is being applied is parked rather than spoken. A pause the
  /// engine refuses puts the flag back: the reading is still playing, and a
  /// queue that thought otherwise would fall silent at the end of the current
  /// run.
  Future<Result<void, AppFailure>> pause() async {
    _paused = true;
    final outcome = await _tts.pause();
    if (outcome.failureOrNull != null) _paused = false;
    return outcome;
  }

  /// Resumes a reading previously [pause]d.
  ///
  /// Either the engine still has the run it was speaking — and continues it,
  /// which on Android means a fresh utterance covering the remainder
  /// (F10-T08) — or the pause landed between two runs and the one that came
  /// due was parked, in which case resuming is what finally speaks it.
  ///
  /// A resume the engine refuses gives the reading up, whichever of those two
  /// it was (F30-T14). Nothing is going to speak after it and no completion is
  /// going to arrive, so a queue that stayed installed would be a reading the
  /// user has been told failed, waiting for somebody else's completion — the
  /// Settings voice preview's, the one thing outside this queue that speaks —
  /// to advance it a run and start talking again. That is the first invariant,
  /// and before this only the parked half of this method kept it.
  ///
  /// With the same one exception [speak] has: a reading that started while
  /// this one was being resumed is the reading the user asked for, so a
  /// refusal arriving after it is neither reported nor allowed to silence it.
  Future<Result<void, AppFailure>> resume() async {
    final generation = _generation;
    final parked = _parked;
    _paused = false;
    _parked = null;
    final outcome = parked == null
        ? await _tts.resume()
        : await _handOver(parked, generation);
    if (outcome.failureOrNull case final failure?) {
      if (_generation != generation) return const Ok(null);
      return Err(await _abandon(failure));
    }
    return const Ok(null);
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
  /// The voice switch is best-effort, the same as it has been since F10-T07: a
  /// `setVoice` that fails leaves the engine on whatever voice it had, and
  /// that is not worth losing a reading over.
  ///
  /// Answers `Ok` without speaking when the user has moved on or paused in the
  /// middle of it — neither is a failure, and in the paused case the utterance
  /// is kept for [resume] rather than dropped.
  Future<Result<void, AppFailure>> _handOver(
    _Utterance utterance,
    int generation,
  ) async {
    _handingOver = true;
    try {
      _currentStarted = false;
      _speaking = utterance;
      if (utterance.voice case final voice?) await _tts.setVoice(voice);
      // Both checked after the voice switch and before speaking, so a [stop]
      // or a [pause] that lands in the middle of it does not get a run spoken
      // over it.
      if (_generation != generation) return const Ok(null);
      if (_paused) {
        _parked = utterance;
        return const Ok(null);
      }
      // Awaited rather than returned, so [_handingOver] stays set until the
      // engine has actually taken the utterance — that window is the whole
      // point of the flag.
      return await _tts.speak(utterance.text);
    } finally {
      _handingOver = false;
    }
  }

  /// Speaks the queue item after the one that just finished — or the one
  /// that just failed, over again (F30-T16).
  ///
  /// Nothing awaits this — an engine event is what triggered it — so a
  /// failure here has no call to answer and is published on [events]
  /// instead. It reads as retryable: a run the engine would not take is the
  /// same kind of refusal a first run's would have been, and «جرّب تاني» is
  /// the right offer.
  Future<void> _advanceTo(_Utterance utterance, int generation) async {
    final outcome = await _handOver(utterance, generation);
    if (_generation != generation) return;
    if (outcome.failureOrNull != null) {
      _clear();
      unawaited(_tts.stop());
      _readingEvents.add(const TtsFailed());
    }
  }

  /// Whether the item the queue is on is worth speaking again rather than
  /// giving the reading up over (F30-T16).
  ///
  /// Four conditions, and each one of them has to hold:
  ///
  /// * The engine called the condition a passing one. A permanent failure
  ///   retried is a second failure and a longer wait before the user is told
  ///   the truth — and `TtsErrorCode.unknown` counts as passing, which is
  ///   deliberate: "we do not know" is the kind the owner retried by hand
  ///   until it worked.
  /// * This item has not been retried already. Twice is a loop the user
  ///   cannot see and cannot get out of.
  /// * There is an item to speak again. An error with nothing installed
  ///   belongs to something outside the queue — the Settings voice preview —
  ///   and is passed on untouched.
  /// * No hand-over is in flight. Nothing of the queue's is speaking in that
  ///   window, so the failure belongs to the reading being replaced; retrying
  ///   on it would speak the incoming item twice, which is the one outcome
  ///   worse than reporting a failure that had already happened.
  bool _shouldRetry(TtsErrorCode code) =>
      code.isTransient &&
      !_retriedCurrent &&
      !_handingOver &&
      _index < _utterances.length;

  /// Turns the engine's own events into the reading's (see [events]), and
  /// moves the queue along.
  void _onEngineEvent(TtsEvent event) {
    switch (event) {
      case TtsStarted():
        _currentStarted = true;
        // The reading starts when its first run does; the others start
        // nothing the consumer did not already know about.
        if (_index == 0) _readingEvents.add(event);

      case TtsContinued():
        // Also a report that the current utterance is speaking — Android
        // sends this instead of a start for the first utterance after a
        // pause, including the first run of a reading begun while the engine
        // was left paused.
        _currentStarted = true;
        _readingEvents.add(event);

      case TtsProgressed(:final start, :final end):
        final speaking = _speaking;
        if (speaking == null) {
          _readingEvents.add(event);
          return;
        }
        _readingEvents.add(
          TtsProgressed(
            start: speaking.readingOffsetFor(start),
            end: speaking.readingOffsetFor(end),
          ),
        );

      case TtsCompleted():
        // Not this queue's to act on: see [_handingOver].
        if (_handingOver) return;
        final next = _index + 1;
        if (next < _utterances.length) {
          _index = next;
          // A fresh queue item gets its own retry (F30-T16).
          _retriedCurrent = false;
          // Read out of the list here, while it is known to be in range,
          // rather than inside the asynchronous step below.
          final utterance = _utterances[next];
          if (_paused) {
            _parked = utterance;
            return;
          }
          unawaited(_advanceTo(utterance, _generation));
          return;
        }
        _clear();
        _readingEvents.add(event);

      case TtsFailed(:final code):
        // The engine names conditions that pass on their own — a voice whose
        // data is still downloading, a network voice that could not fetch
        // its audio — and until F30-T16 every one of them reached the user
        // as «حصلت مشكلة. جرّب تاني.» and made them tap again by hand. That
        // is RC-2, and the owner's reading working on the third attempt is
        // what it looks like. The app does that one tap itself now, in
        // silence: nothing is published, so no bar closes and no message
        // appears, and the paper carries on from the item that failed.
        if (_shouldRetry(code)) {
          _retriedCurrent = true;
          unawaited(_advanceTo(_utterances[_index], _generation));
          return;
        }
        // The reading is over however many runs were left: the engine has
        // stopped, and nothing will complete to carry the queue forward.
        _clear();
        _readingEvents.add(event);

      case TtsCancelled():
        // A cancel is not only what a [stop] produces. The engine reports one
        // for the utterance a *newly* started reading just flushed, and that
        // one arrives after the new reading is already installed — so
        // clearing on every cancel would throw away the queue of the reading
        // the user just asked for. A cancel that interrupts a run the engine
        // had told us was speaking is the other kind: something outside this
        // queue took the engine (the Settings voice preview is the one thing
        // that can), and the runs behind it are not going to be read.
        if (_currentStarted) _clear();
        _readingEvents.add(event);

      case TtsPaused():
        _readingEvents.add(event);
    }
  }

  /// One utterance per run — or several, when a run is longer than the engine
  /// will take — each knowing where it starts in the reading and which voice
  /// reads it.
  ///
  /// An English run on a device with no English voice is written in Arabic
  /// letters and read by the Arabic voice (F30-T17) — «إنفويس» for `invoice`
  /// — because an Arabic voice handed Latin script names the characters one
  /// at a time, which is the owner's own symptom (RC-4). Dropping the run
  /// instead would be worse still: it would read the paper with a piece of
  /// it missing and say nothing about that.
  ///
  /// A run with no voice and nothing to fall back on keeps `null` and is read
  /// in whatever voice the engine already had. That is the device with no
  /// voices at all, where there is nothing to prefer and no evidence either —
  /// Android answers with an empty list while it is still binding.
  ///
  /// [limit] is the engine's own ceiling on one utterance, `null` when the
  /// platform declares none (F30-T15). Anything over it is cut into pieces
  /// that are under it, after transliteration rather than before, so the
  /// ceiling holds against what is actually spoken.
  List<_Utterance> _queueFor(
    List<LanguageRun> runs,
    List<TtsVoice> voices,
    int? limit,
  ) {
    final utterances = <_Utterance>[];
    var offset = 0;
    for (final run in runs) {
      var voice = voices.isEmpty
          ? null
          : _selectVoice.forLanguage(run.language, voices);
      var spoken = run.text;
      if (voice == null && run.language == ReadingLanguage.english) {
        final arabic = _selectVoice.forLanguage(ReadingLanguage.arabic, voices);
        if (arabic != null) {
          voice = arabic;
          spoken = _transliterate(run.text);
        }
      }
      utterances.addAll(
        _piecesOf(spoken, run.text.length, offset, voice, limit),
      );
      offset += run.text.length;
    }
    return utterances;
  }

  /// [spoken] as queue items the engine will take, together covering
  /// [sourceLength] code units of the reading from [offset].
  ///
  /// The pieces divide what they cover in proportion to what each of them
  /// says, which is an identity when [spoken] is the reading's own
  /// characters and an approximation when it was transliterated — see
  /// [_Utterance.readingOffsetFor], which the progress offsets inside one
  /// piece go through for the same reason.
  Iterable<_Utterance> _piecesOf(
    String spoken,
    int sourceLength,
    int offset,
    TtsVoice? voice,
    int? limit,
  ) sync* {
    final pieces = _chunk(spoken, limit: limit);
    var saidSoFar = 0;
    var covered = 0;
    for (var i = 0; i < pieces.length; i++) {
      saidSoFar += pieces[i].length;
      // The last piece takes whatever is left rather than its own share, so
      // rounding cannot leave a code unit of the reading uncovered.
      final end = i == pieces.length - 1
          ? sourceLength
          : (saidSoFar * sourceLength / spoken.length).round();
      yield _Utterance(
        text: pieces[i],
        offset: offset + covered,
        length: end - covered,
        voice: voice,
      );
      covered = end;
    }
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

  /// Installs a reading, from a clean slate — a new reading is never paused
  /// and never inherits a parked run from the one before it.
  void _install(List<_Utterance> utterances) {
    _clear();
    _utterances = utterances;
  }

  /// Gives up the reading and leaves the engine silent, answering with
  /// [failure] so the caller can report it.
  ///
  /// A `stop` that itself fails is not reported over the failure that brought
  /// us here: the caller asked for a reading, and that is the answer it is
  /// owed.
  Future<AppFailure> _abandon(AppFailure failure) async {
    _clear();
    await _tts.stop();
    return failure;
  }

  /// Forgets the installed reading. Does **not** touch [_generation]: a
  /// [speak] that is mid-flight has already claimed it, and invalidating it
  /// here would stand that reading down before it ever spoke.
  void _clear() {
    _utterances = const [];
    _index = 0;
    _speaking = null;
    _currentStarted = false;
    _paused = false;
    _parked = null;
    _retriedCurrent = false;
  }
}

/// One queued utterance: what the engine is told to say, which part of the
/// reading that covers, and the voice to say it with.
final class _Utterance {
  const _Utterance({
    required this.text,
    required this.offset,
    required this.length,
    required this.voice,
  });

  /// What the engine is asked to speak.
  ///
  /// Usually a verbatim slice of the reading, and not always: a run
  /// transliterated into Arabic (F30-T17) says the same words in different
  /// letters, and in a different number of them.
  final String text;

  /// Where this utterance begins in the whole reading, in UTF-16 code units.
  final int offset;

  /// How much of the reading it covers, in UTF-16 code units — [text]'s own
  /// length except when [text] was transliterated.
  ///
  /// Progress is reported against the reading the user can see, so it is
  /// this and not [text] that the bar is measured in.
  final int length;

  /// `null` to read it with whatever voice the engine already has — see
  /// [ReadingQueue._queueFor].
  final TtsVoice? voice;

  /// [spokenOffset], which the engine counts from the start of [text], as an
  /// offset into the whole reading.
  ///
  /// A plain shift while [text] is the reading's own characters. For a
  /// transliterated utterance there is no character-for-character answer —
  /// «إنفويس» is six letters where `invoice` is seven — so the offset is
  /// scaled, which is monotonic, starts at [offset] and ends exactly at the
  /// end of what this utterance covers. That is everything a progress bar
  /// asks of it.
  int readingOffsetFor(int spokenOffset) {
    if (text.length == length) return offset + spokenOffset;
    if (text.isEmpty) return offset;
    final scaled = (spokenOffset * length / text.length).round();
    return offset + scaled.clamp(0, length);
  }
}
