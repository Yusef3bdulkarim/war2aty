import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart' as ft;

import '../../../../core/audio/tts_error_code.dart';
import '../../../../core/audio/tts_voice.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/tts_event.dart';
import '../../domain/services/text_to_speech_service.dart';

/// [TextToSpeechService] backed by `flutter_tts`, wrapping the OS's own
/// engine (Android `TextToSpeech`, iOS `AVSpeechSynthesizer`) — nothing here
/// talks to a network.
///
/// This is the only file allowed to import `package:flutter_tts` — the rest
/// of the app speaks [TextToSpeechService], the same boundary
/// `TesseractOcrEngine` and `FlutterLocalNotificationsPort` keep for their
/// own plugins.
final class FlutterTtsTextToSpeechService implements TextToSpeechService {
  FlutterTtsTextToSpeechService(this._logger, [ft.FlutterTts? tts])
    : _tts = tts ?? ft.FlutterTts() {
    _tts
      ..setStartHandler(() => _events.add(const TtsStarted()))
      ..setCompletionHandler(() {
        _lastSpokenText = null;
        _events.add(const TtsCompleted());
      })
      ..setPauseHandler(() => _events.add(const TtsPaused()))
      ..setContinueHandler(() => _events.add(const TtsContinued()))
      ..setCancelHandler(() {
        _lastSpokenText = null;
        _events.add(const TtsCancelled());
      })
      ..setErrorHandler(_onEngineError)
      ..setProgressHandler(
        (text, start, end, word) =>
            _events.add(TtsProgressed(start: start, end: end)),
      );
  }

  final ft.FlutterTts _tts;

  /// F27's logging, so an engine error leaves a trace in production — the
  /// half of F30 RC-2 the user never sees. Only the classified code is ever
  /// recorded: the engine's message is free text and never leaves this file
  /// (§51).
  final AppLogger _logger;

  final _events = StreamController<TtsEvent>.broadcast();

  /// The text last handed to [speak].
  ///
  /// `flutter_tts` has no distinct "resume" call — its Android/iOS sides
  /// resume a paused utterance when `speak()` is sent the exact same text
  /// again, so [resume] replays it from here instead.
  String? _lastSpokenText;

  @override
  Stream<TtsEvent> get events => _events.stream;

  /// Turns the engine's error payload into a classified [TtsFailed], and
  /// leaves a log line behind (F30-T08).
  ///
  /// This handler used to be `(_) => _events.add(const TtsFailed())`: the
  /// payload — the only thing that says whether a voice is still downloading
  /// or the engine is gone — was dropped on the floor, which is F30 RC-2 in
  /// one line.
  void _onEngineError(Object? payload) {
    final code = _parseErrorCode(payload);
    // The user hears about it first: logging is the part production needs,
    // not the part the person holding the phone is waiting for, and a sink
    // that throws must not be what swallows their failure.
    _events.add(TtsFailed(code: code));
    _logger.failure(
      code.isTransient ? TtsFailure(code) : TtsEngineUnavailableFailure(code),
    );
  }

  /// The engine's free-text error payload, read as a [TtsErrorCode].
  ///
  /// `flutter_tts`'s Android side sends
  /// `"Error from TextToSpeech (speak) - $errorCode"`, where the number is
  /// one of `android.speech.tts.TextToSpeech`'s constants — and, from the
  /// older `onError(utteranceId)` callback, the same sentence with no number
  /// at all. iOS sends nothing here: its side reports no error. So anything
  /// that is not a recognised negative constant reads as
  /// [TtsErrorCode.unknown], which is the retryable kind.
  ///
  /// The message itself goes no further than this method, by design: it is
  /// free text, and free text is what must never reach a log line (§51).
  static TtsErrorCode _parseErrorCode(Object? payload) {
    if (payload is! String) return TtsErrorCode.unknown;
    final trailingNumber = RegExp(r'(-?\d+)\s*$').firstMatch(payload);
    if (trailingNumber == null) return TtsErrorCode.unknown;
    return switch (int.tryParse(trailingNumber.group(1)!)) {
      -3 => TtsErrorCode.synthesis,
      -4 => TtsErrorCode.service,
      -5 => TtsErrorCode.output,
      -6 => TtsErrorCode.network,
      -7 => TtsErrorCode.networkTimeout,
      -8 => TtsErrorCode.invalidRequest,
      -9 => TtsErrorCode.notInstalledYet,
      // -1 `ERROR` says only "something went wrong", and -2 `STOPPED` is not
      // an error at all. Both are as unexplained as a message with no number.
      _ => TtsErrorCode.unknown,
    };
  }

  /// The longest the engine may take to *accept* an utterance (F30-T09).
  ///
  /// Not how long a reading may take: with `awaitSpeakCompletion` left off —
  /// this app never turns it on — the platform answers as soon as it has
  /// taken the text, which is immediate on a warm engine (F30-T06 makes sure
  /// it is warm). Generous on purpose, because one of the two refusals below
  /// recovers by itself and is worth waiting out.
  static const _acceptanceBound = Duration(seconds: 5);

  @override
  Future<Result<void, AppFailure>> speak(String text) async {
    try {
      _lastSpokenText = text;
      // `1` means the platform took the utterance; `0` means it declined it
      // — on iOS, a paused synthesizer that would not continue. Anything
      // else is not an answer we know how to trust, and before T09 all of
      // them returned `Ok`.
      final accepted = await _tts
          .speak(text)
          .timeout(_acceptanceBound, onTimeout: () => null);
      if (accepted != 1) return _couldNotSpeak(text);
      return const Ok(null);
    } on Object {
      return _couldNotSpeak(text);
    }
  }

  /// The engine never took [text], so nothing is being read (F30-T09).
  ///
  /// Reported rather than swallowed, because the caller's `Ok` used to
  /// become an `AudioReaderReading`: the mini-player appeared over an engine
  /// that was saying nothing, and since no completion event was coming
  /// either, it stayed there (F30 RC-3).
  ///
  /// On Android the refusal does not arrive as an answer at all. The plugin
  /// parks the call and re-runs it the next time the engine initialises, so
  /// the future simply never completes — which is why [_acceptanceBound] is
  /// here. Two things reach it: an engine whose service connection had gone
  /// stale, where the plugin builds a new engine and the parked call then
  /// succeeds on its own, usually well inside the bound; and a native
  /// `speak()` that failed outright, most often text longer than
  /// `getMaxSpeechInputLength` (4000 characters), where nothing re-triggers
  /// initialisation and the call would hang for the rest of the session.
  /// T15's chunking removes that second trigger; this keeps the screen
  /// honest in the meantime.
  ///
  /// The one case the bound cannot cover: a parked call that lands *after*
  /// it starts the engine speaking with the bar already gone, so there is
  /// nothing on screen to stop it with. That is why five seconds and not
  /// one — the self-healing case has to finish inside the bound, not race
  /// it.
  Result<void, AppFailure> _couldNotSpeak(String text) {
    // Only if nothing else has started since: a second tap that is already
    // reading must keep its own text for [resume] to replay.
    if (_lastSpokenText == text) _lastSpokenText = null;
    _logger.failure(const TtsFailure());
    return const Err(TtsFailure());
  }

  @override
  Future<Result<void, AppFailure>> pause() async {
    try {
      await _tts.pause();
      return const Ok(null);
    } on Object {
      return const Err(TtsFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> resume() async {
    final text = _lastSpokenText;
    if (text == null) return const Ok(null);
    return speak(text);
  }

  @override
  Future<Result<void, AppFailure>> stop() async {
    try {
      _lastSpokenText = null;
      await _tts.stop();
      return const Ok(null);
    } on Object {
      return const Err(TtsFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> setSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
      return const Ok(null);
    } on Object {
      return const Err(TtsFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> setVoice(TtsVoice voice) async {
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      return const Ok(null);
    } on Object {
      return const Err(TtsFailure());
    }
  }

  /// The device's voices, once asked for — see [forgetVoices] for why they
  /// are kept at all, and for the one thing that clears them.
  List<TtsVoice>? _cachedVoices;

  @override
  Future<Result<List<TtsVoice>, AppFailure>> getVoices() async {
    if (_cachedVoices case final cached?) return Ok(cached);
    try {
      final raw = (await _tts.getVoices) as List<dynamic>?;
      final voices = (raw ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(_parseVoice)
          .whereType<TtsVoice>()
          .toList(growable: false);
      // An empty answer is never cached. Android reports no voices at all
      // while its engine is still binding, and remembering that would mean
      // "this device has no voices" for the rest of the session — which
      // F30-T07 would then report to the user as a missing Arabic voice.
      if (voices.isNotEmpty) _cachedVoices = voices;
      return Ok(voices);
    } on Object {
      return const Err(TtsFailure());
    }
  }

  @override
  void forgetVoices() => _cachedVoices = null;

  /// The limit once the platform has given one — a constant per platform
  /// (`TextToSpeech.getMaxSpeechInputLength()` is a fixed 4000), so asking
  /// twice can only get the same answer, and asking at all is a channel
  /// round trip on a path F30 RC-6 is about keeping short.
  int? _cachedMaxInputLength;

  @override
  Future<int?> getMaxInputLength() async {
    if (_cachedMaxInputLength case final cached?) return cached;
    try {
      final length = await _tts.getMaxSpeechInputLength;
      // A missing or nonsensical answer is "no limit declared", and is not
      // remembered — for the same reason an empty voice list is not
      // (`getVoices` above). Caching it would turn one bad answer into a
      // session with no chunking at all, and that session's long paper is
      // the reading that hangs.
      if (length == null || length <= 0) return null;
      return _cachedMaxInputLength = length;
    } on Object {
      // iOS lands here every time: its side does not implement the call, so
      // the channel throws. Nothing to log — the absence of a limit is the
      // platform's normal answer, not a fault.
      return null;
    }
  }

  /// One entry from `getVoices`, or `null` if it carries no name or locale —
  /// without both there is nothing to select it by later.
  ///
  /// The two platforms describe a voice differently and neither is complete:
  /// Android sends `quality`, `latency`, `network_required` and `features`;
  /// iOS sends `quality` (in a vocabulary of its own), `gender` and
  /// `identifier`, and no latency or network field at all. Anything missing
  /// or unrecognised reads as "unknown", which ranks level with ordinary
  /// rather than last — see [TtsVoiceQuality.unknown].
  static TtsVoice? _parseVoice(Map<dynamic, dynamic> raw) {
    final name = raw['name'] as String?;
    final locale = raw['locale'] as String?;
    if (name == null || locale == null) return null;
    return TtsVoice(
      name: name,
      locale: locale,
      quality: _parseQuality(raw['quality'] as String?),
      latency: _parseLatency(raw['latency'] as String?),
      // Android sends the flag as "1"/"0". A platform that sends nothing is
      // taken as on-device, which is what iOS's voices are.
      networkRequired: raw['network_required'] == '1',
    );
  }

  static TtsVoiceQuality _parseQuality(String? raw) => switch (raw) {
    'very high' => TtsVoiceQuality.veryHigh,
    'high' => TtsVoiceQuality.high,
    'normal' => TtsVoiceQuality.normal,
    'low' => TtsVoiceQuality.low,
    'very low' => TtsVoiceQuality.veryLow,
    // iOS's own three, which say nothing about Android's five-step scale
    // beyond their order: premium is the best it offers, default the
    // baseline.
    'premium' => TtsVoiceQuality.veryHigh,
    'enhanced' => TtsVoiceQuality.high,
    'default' => TtsVoiceQuality.normal,
    _ => TtsVoiceQuality.unknown,
  };

  static TtsVoiceLatency _parseLatency(String? raw) => switch (raw) {
    'very low' => TtsVoiceLatency.veryLow,
    'low' => TtsVoiceLatency.low,
    'normal' => TtsVoiceLatency.normal,
    'high' => TtsVoiceLatency.high,
    'very high' => TtsVoiceLatency.veryHigh,
    _ => TtsVoiceLatency.unknown,
  };
}
