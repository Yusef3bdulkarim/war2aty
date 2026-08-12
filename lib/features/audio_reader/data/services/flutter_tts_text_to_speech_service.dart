import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart' as ft;

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/tts_event.dart';
import '../../domain/entities/tts_voice.dart';
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

  @override
  Future<Result<List<TtsVoice>, AppFailure>> getVoices() async {
    try {
      final raw = (await _tts.getVoices) as List<dynamic>?;
      final voices = (raw ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(_parseVoice)
          .whereType<TtsVoice>()
          .toList(growable: false);
      return Ok(voices);
    } on Object {
      return const Err(TtsFailure());
    }
  }

  static TtsVoice? _parseVoice(Map<dynamic, dynamic> raw) {
    final name = raw['name'] as String?;
    final locale = raw['locale'] as String?;
    if (name == null || locale == null) return null;
    return TtsVoice(name: name, locale: locale);
  }
}
