import 'dart:async';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/voice/encrypted_audio_store.dart';
import '../entities/live_voice_event.dart';
import '../entities/spoken_card_span.dart';
import '../entities/transcript_audio_anchor.dart';
import '../entities/voice_engine.dart';
import '../entities/voice_read_event.dart';
import '../entities/voice_read_outcome.dart';
import '../entities/voice_segment.dart';
import '../services/audio_encoder.dart';
import '../services/device_voice_reader.dart';
import '../services/live_voice_session.dart';
import '../services/pcm_audio_sink.dart';
import 'align_segments_to_audio.dart';
import 'build_voice_turn_text.dart';
import 'verify_verbatim_read.dart';

/// Reads a page aloud, choosing and falling between the tiers (F37-T17).
///
/// This is the spine's only entry point, and the one place that knows there is
/// more than one way to read a paper. Everything under it was built to do one
/// thing and report: the session streams frames, the sink plays, the encoder
/// writes, the verifier compares, the aligner places. The decisions — retry or
/// give up, keep the audio or throw it away, trust the read or mark it — all
/// live here.
///
/// **The ladder, in order:**
///
/// 1. **Gemini Live.** Streamed, played as it lands, encoded alongside, and
///    checked against the service's own transcription of its own speech.
/// 2. **Early abort.** The transcription is compared against the beginning of
///    the page as it arrives; a reading that is paraphrasing is abandoned at
///    the third second rather than the fortieth.
/// 3. **One retry.** A Live attempt that aborted, or dropped before the user
///    heard [minHeardBeforeLiveRestart], is tried once more. Never twice: each
///    attempt costs about 75 seconds of someone's time.
/// 4. **Device TTS.** The paper is read by the phone's own engine. No file is
///    saved, and the reading is verbatim by construction.
/// 5. **Nothing left.** [VoiceReadFailed] carries why, and the screen says it
///    out loud from the bundled fixed lines (T20) — never from either engine,
///    which is the point of bundling them. A [NoArabicVoiceFailure] arrives
///    here intact so the screen can offer the system TTS settings (F30-T07);
///    this use case does not open them itself, because throwing a user into
///    system settings without a tap is a decision for the screen, not the
///    domain.
///
/// **What it never does:** log the transcript, the page, or any part of
/// either. They are document content (CLAUDE.md §7). The only number worth
/// recording about a failed comparison is the word error rate, which
/// [VoiceReadNotVerbatimFailure] carries.
final class ReadPaperAloud {
  ReadPaperAloud({
    required LiveVoiceSession Function() openSession,
    required PcmAudioSink sink,
    required AudioEncoder encoder,
    required EncryptedAudioStore audioStore,
    required DeviceVoiceReader deviceReader,
    required VerifyVerbatimRead verify,
    required AlignSegmentsToAudio align,
    BuildVoiceTurnText buildTurn = const BuildVoiceTurnText(),
    Duration drainGrace = const Duration(seconds: 2),
  }) : _openSession = openSession,
       _sink = sink,
       _encoder = encoder,
       _audioStore = audioStore,
       _deviceReader = deviceReader,
       _verify = verify,
       _align = align,
       _buildTurn = buildTurn,
       _drainGrace = drainGrace;

  /// A factory, not a session: a [LiveVoiceSession] is single-use, so the
  /// retry needs a second one.
  final LiveVoiceSession Function() _openSession;

  final PcmAudioSink _sink;
  final AudioEncoder _encoder;
  final EncryptedAudioStore _audioStore;
  final DeviceVoiceReader _deviceReader;
  final VerifyVerbatimRead _verify;
  final AlignSegmentsToAudio _align;
  final BuildVoiceTurnText _buildTurn;

  /// How long to keep waiting for the speaker's own clock to reach the end of
  /// the audio before stopping it anyway.
  ///
  /// Only a guard against a clock that stalls: the wait normally ends the
  /// moment the last frame is played.
  final Duration _drainGrace;

  /// How many Live attempts a single read may spend.
  ///
  /// Two: the first, and the one retry. A third would cost another 75 seconds
  /// against a service that has already failed the same page twice, while the
  /// device can read it now.
  static const int maxLiveAttempts = 2;

  /// Below this, restarting Live is better than falling to the device.
  ///
  /// The Live API cannot replay a partial turn — reconnecting restarts from
  /// word one — so a drop any further in than this would make the user hear
  /// the beginning of their paper twice.
  static const Duration minHeardBeforeLiveRestart = Duration(seconds: 2);

  /// Reads [segments] aloud, in page order.
  ///
  /// The returned stream is single-subscription and the read starts when it is
  /// listened to. [audioId] is the key the encrypted `.m4a` is stored under —
  /// an opaque string, deliberately not a document id, so the spine stays
  /// clear of F36's schema.
  /// Cancelling the returned subscription stops the reading: the session is
  /// abandoned, the speaker released and any partial file discarded. That is
  /// how a user leaving the screen stops the voice — and why it also frees the
  /// Live session, which is the scarce resource on this service.
  Stream<VoiceReadEvent> call({
    required List<VoiceSegment> segments,
    required String audioId,
  }) {
    final out = StreamController<VoiceReadEvent>();
    final read = _Read();
    out.onListen = () {
      unawaited(_run(out, read, segments, audioId));
    };
    out.onCancel = () async {
      read.cancelled = true;
      // Closing the session's own stream is what ends the frame loop; the
      // tiers then unwind through their normal clean-up.
      await read.session?.cancel();
      await _deviceReader.stop();
    };
    return out.stream;
  }

  Future<void> _run(
    StreamController<VoiceReadEvent> out,
    _Read read,
    List<VoiceSegment> segments,
    String audioId,
  ) async {
    try {
      final turn = _buildTurn(segments);

      // A page with nothing on it is refused before any engine is touched,
      // with the same failure `ReadingQueue.speak` answers an empty reading
      // with.
      if (turn.text.trim().isEmpty) {
        out.add(const VoiceReadFailed(TtsFailure()));
        return;
      }

      for (var attempt = 1; attempt <= maxLiveAttempts; attempt++) {
        final outcome = await _readOnLive(out, read, turn, segments, audioId);
        if (read.cancelled) return;
        if (outcome == _LiveOutcome.done) return;
        if (outcome == _LiveOutcome.fallBack) break;
        // _LiveOutcome.retry — one more Live attempt, if one is left.
      }

      await _readOnDevice(out, turn);
    } catch (_) {
      // A tier threw where its contract says it reports — a platform channel
      // with no host behind it, say. The read is over either way, and the one
      // thing that must not happen is a stream left open on a screen waiting
      // to be told something (CLAUDE.md §3: no silent failures).
      if (!read.cancelled) out.add(const VoiceReadFailed(TtsFailure()));
    } finally {
      if (!out.isClosed) await out.close();
    }
  }

  // ---------------------------------------------------------------------
  // Tier 1 — Gemini Live
  // ---------------------------------------------------------------------

  Future<_LiveOutcome> _readOnLive(
    StreamController<VoiceReadEvent> out,
    _Read read,
    VoiceTurnText turn,
    List<VoiceSegment> segments,
    String audioId,
  ) async {
    final session = read.session = _openSession();
    final format = session.format;

    // The speaker is reserved before the session is opened: a session the
    // device cannot play into is a free-tier session spent on silence.
    if ((await _sink.open(format)).isErr) {
      await session.cancel();
      return _LiveOutcome.fallBack;
    }

    // A read that cannot be *saved* is still a read. The user hears their
    // paper; all that is lost is the offline replay.
    final canSave = (await _encoder.begin(format)).isOk;

    if ((await session.start(turn.text)).isErr) {
      await _abandonLive(session, canSave: canSave);
      return _LiveOutcome.fallBack;
    }

    // Each attempt announces itself. A retry restarts Live from word one, so a
    // screen that resets its highlight on this is doing the right thing.
    out.add(const VoiceReadStarted(VoiceEngine.geminiLive));

    var spans = const <SpokenCardSpan>[];
    var lastPosition = Duration.zero;
    Duration? drainTarget;
    Completer<void>? drained;

    final positionSub = _sink.position.listen((position) {
      lastPosition = position;
      out.add(
        VoiceReadPositionChanged(
          position: position,
          segmentId: _segmentAt(spans, position),
        ),
      );
      final waiter = drained;
      final target = drainTarget;
      if (waiter != null && target != null && !waiter.isCompleted) {
        if (position >= target) waiter.complete();
      }
    });

    final transcript = StringBuffer();
    final anchors = <TranscriptAudioAnchor>[];
    var audioBytes = 0;
    var chunksSinceDelta = 0;
    var abortedNotVerbatim = false;
    var turnComplete = false;
    AppFailure? lost;

    try {
      await for (final event in session.events) {
        switch (event) {
          case LivePcmChunk(:final bytes):
            audioBytes += bytes.length;
            chunksSinceDelta++;
            // Awaited, not fired off: the sink's write blocks until the hardware
            // can take the chunk, which is what paces this loop to the speed of
            // speech instead of the speed of the socket.
            await _sink.write(bytes);
            if (canSave) await _encoder.feed(bytes);

          case LiveTranscriptDelta(:final text):
            transcript.write(text);
            // An anchor is only worth having when the frame that carried this
            // text also carried audio — otherwise the byte count measures
            // arrival, not speech. The union flattens frames, so the closest
            // honest proxy is: audio has arrived since the previous delta.
            if (chunksSinceDelta > 0) {
              anchors.add(
                TranscriptAudioAnchor(
                  transcriptSoFar: transcript.toString(),
                  audioBytesSoFar: audioBytes,
                ),
              );
              chunksSinceDelta = 0;
            }
            final prefix = _verify.checkPrefix(
              source: turn.text,
              heard: transcript.toString(),
            );
            // Only the widest band aborts a read in flight: the 5 % band is for
            // a finished read, and applying it to a fragment would abandon reads
            // that go on to be perfect.
            if (prefix != null &&
                prefix.verdict == VerbatimVerdict.notVerbatim) {
              abortedNotVerbatim = true;
            }

          case LiveTurnComplete():
            turnComplete = true;

          case LiveSessionLost(:final failure):
            lost = failure;
        }

        if (abortedNotVerbatim || turnComplete || lost != null) break;
      }
    } catch (_) {
      // The sink reports a dead platform channel by throwing, not with a
      // `Result` (T13), so a phone whose audio host is missing lands here.
      // Everything is released and the device's own engine gets the paper.
      await _abandonLive(session, canSave: canSave, positionSub: positionSub);
      return _LiveOutcome.fallBack;
    }

    if (read.cancelled) {
      await _abandonLive(session, canSave: canSave, positionSub: positionSub);
      return _LiveOutcome.fallBack;
    }

    if (abortedNotVerbatim || lost != null) {
      // Nothing of a partial read is kept. A saved paper whose replay stops
      // mid-sentence, permanently, is worse than one with no audio at all.
      await _abandonLive(session, canSave: canSave, positionSub: positionSub);
      return _retryOrFallBack(
        abortedNotVerbatim: abortedNotVerbatim,
        lost: lost,
      );
    }

    if (!turnComplete) {
      // The stream closed without saying how it ended. Treat it as a drop.
      await _abandonLive(session, canSave: canSave, positionSub: positionSub);
      return _LiveOutcome.fallBack;
    }

    // Live has finished *sending*, which at roughly twice real time is about
    // halfway through what the user is hearing — so the spans land while the
    // paper is still being spoken, which is the whole point of them.
    spans = _align(
      segments: segments,
      transcript: transcript.toString(),
      anchors: anchors,
      totalAudioBytes: audioBytes,
      format: format,
    );
    out.add(VoiceReadSpansResolved(spans));

    final duration = format.durationOfBytes(audioBytes);
    if (lastPosition < duration) {
      drainTarget = duration;
      final waiter = drained = Completer<void>();
      await waiter.future.timeout(
        duration - lastPosition + _drainGrace,
        onTimeout: () {},
      );
    }

    await _release(_sink.stop);
    await _release(positionSub.cancel);
    await _release(session.cancel);

    final audioSaved = canSave && await _saveAudio(audioId);

    // The final comparison, over the whole page. A divergence found this late
    // cannot be un-heard, so the audio is kept and the doubt is recorded
    // instead of spending another 75 seconds re-reading it (F38 reads this).
    final comparison = _verify(source: turn.text, heard: transcript.toString());

    out.add(
      VoiceReadCompleted(
        VoiceReadOutcome(
          engine: VoiceEngine.geminiLive,
          duration: duration,
          verified: comparison.verdict == VerbatimVerdict.verbatim,
          audioSaved: audioSaved,
          spans: spans,
        ),
      ),
    );
    return _LiveOutcome.done;
  }

  _LiveOutcome _retryOrFallBack({
    required bool abortedNotVerbatim,
    required AppFailure? lost,
  }) {
    if (abortedNotVerbatim) return _LiveOutcome.retry;
    if (lost is VoiceStreamInterruptedFailure &&
        lost.heard < minHeardBeforeLiveRestart) {
      return _LiveOutcome.retry;
    }
    return _LiveOutcome.fallBack;
  }

  Future<bool> _saveAudio(String audioId) async {
    final encoded = await _encoder.finish();
    return switch (encoded) {
      Ok(:final value) => (await _audioStore.store(
        id: audioId,
        audioBytes: value,
      )).isOk,
      Err() => false,
    };
  }

  /// Releases everything the Live tier holds, in the order that matters.
  ///
  /// The sink is stopped before the next tier starts, because `AudioTrack` and
  /// `flutter_tts` must never both own the speaker (T11), and the session is
  /// cancelled on every path because concurrent sessions are the scarce
  /// resource on this service — a socket left open denies the next user a
  /// voice.
  Future<void> _abandonLive(
    LiveVoiceSession session, {
    required bool canSave,
    StreamSubscription<Duration>? positionSub,
  }) async {
    if (canSave) await _release(_encoder.abort);
    await _release(_sink.stop);
    if (positionSub != null) await _release(positionSub.cancel);
    await _release(session.cancel);
  }

  /// Runs one release step, absorbing a throw from it.
  ///
  /// Every caller is already past the point of deciding anything: the paper has
  /// either been read or abandoned. A speaker that throws on its way out must
  /// not skip the session cancel behind it — that socket is the scarce resource
  /// — and must not turn a paper the user *heard* into a read the screen says
  /// failed, which is what an escaping throw would do via [_run]'s guard.
  ///
  /// Nothing is logged: there is nothing to recover, and the only things in
  /// reach are document content (CLAUDE.md §7).
  Future<void> _release(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      // The tier is over either way.
    }
  }

  // ---------------------------------------------------------------------
  // Tier 2 — the device's own engine
  // ---------------------------------------------------------------------

  Future<void> _readOnDevice(
    StreamController<VoiceReadEvent> out,
    VoiceTurnText turn,
  ) async {
    out.add(const VoiceReadStarted(VoiceEngine.deviceTts));

    var spans = const <SpokenCardSpan>[];
    final sub = _deviceReader.events.listen((event) {
      if (event is VoiceReadSpansResolved) spans = event.spans;
      out.add(event);
    });

    final outcome = await _deviceReader.read(turn);
    await sub.cancel();

    switch (outcome) {
      case Ok(:final value):
        out.add(
          VoiceReadCompleted(
            VoiceReadOutcome(
              engine: VoiceEngine.deviceTts,
              duration: value,
              // True by construction: the device speaks the exact string it
              // was handed and has no capacity to reword it.
              verified: true,
              audioSaved: false,
              spans: spans,
            ),
          ),
        );
      case Err(:final failure):
        out.add(VoiceReadFailed(failure));
    }
  }

  String? _segmentAt(List<SpokenCardSpan> spans, Duration position) {
    for (final span in spans) {
      if (span.contains(position)) return span.segmentId;
    }
    return null;
  }
}

/// The mutable part of one read: what the cancel callback has to reach.
///
/// A class rather than two captured locals because `onCancel` is installed
/// before the read begins and has to see the session the ladder is on *now* —
/// a retry is a different session, and cancelling the first one would leave
/// the second talking.
final class _Read {
  bool cancelled = false;
  LiveVoiceSession? session;
}

/// How one Live attempt ended, from the ladder's point of view.
enum _LiveOutcome {
  /// The paper was read; there is nothing left to do.
  done,

  /// Worth one more Live attempt, if one is left.
  retry,

  /// Live cannot read this paper now; the device's turn.
  fallBack,
}
