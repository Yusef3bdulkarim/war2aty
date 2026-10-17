import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart' as ft;

import '../../../../core/audio/tts_voice.dart';
import '../../../../core/error/app_failure.dart';
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
  FlutterTtsTextToSpeechService([ft.FlutterTts? tts])
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
      ..setErrorHandler((_) => _events.add(const TtsFailed()))
      ..setProgressHandler(
        (text, start, end, word) =>
            _events.add(TtsProgressed(start: start, end: end)),
      );
  }

  final ft.FlutterTts _tts;
  final _events = StreamController<TtsEvent>.broadcast();

  /// The text last handed to [speak].
  ///
  /// `flutter_tts` has no distinct "resume" call — its Android/iOS sides
  /// resume a paused utterance when `speak()` is sent the exact same text
  /// again, so [resume] replays it from here instead.
  String? _lastSpokenText;

  @override
  Stream<TtsEvent> get events => _events.stream;

  @override
  Future<Result<void, AppFailure>> speak(String text) async {
    try {
      _lastSpokenText = text;
      await _tts.speak(text);
      return const Ok(null);
    } on Object {
      return const Err(TtsFailure());
    }
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
