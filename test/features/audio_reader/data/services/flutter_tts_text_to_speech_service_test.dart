import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart' as ft;
import 'package:war2aty/core/audio/tts_error_code.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/data/services/flutter_tts_text_to_speech_service.dart';
import 'package:war2aty/features/audio_reader/domain/entities/tts_event.dart';
import 'package:war2aty/features/audio_reader/domain/services/text_to_speech_service.dart';

/// F30-T03. The data layer's own tests, which this service never had.
///
/// It is the one file allowed to import `flutter_tts`, so it is also the only
/// place the platform's voice vocabulary is understood — and until T03 it read
/// two of the six fields the plugin sends and dropped the rest, which is how
/// the reader ended up choosing network-synthesised voices blind (F30 RC-6).
void main() {
  // `FlutterTts`'s constructor installs a method-call handler on its channel,
  // so the fake below needs a binding even though no call is ever made.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterTtsTextToSpeechService.getVoices', () {
    test('reads the two fields that identify a voice', () async {
      final voices = await _voicesFrom([
        {'name': 'ar-eg-x-ard#male_1-local', 'locale': 'ar-EG'},
      ]);

      expect(voices, hasLength(1));
      expect(voices.single.name, 'ar-eg-x-ard#male_1-local');
      expect(voices.single.locale, 'ar-EG');
    });

    test('reads all four of Android\'s descriptive fields', () async {
      final voices = await _voicesFrom([
        {
          'name': 'ar-EG-local',
          'locale': 'ar-EG',
          'quality': 'very high',
          'latency': 'very low',
          'network_required': '0',
          'features': 'embeddedTts',
        },
      ]);

      expect(voices.single.quality, TtsVoiceQuality.veryHigh);
      expect(voices.single.latency, TtsVoiceLatency.veryLow);
      expect(voices.single.networkRequired, isFalse);
    });

    test('a network voice is marked as one', () async {
      final voices = await _voicesFrom([
        {
          'name': 'ar-EG-network',
          'locale': 'ar-EG',
          'latency': 'very high',
          'network_required': '1',
        },
      ]);

      // The whole point of T03: this is the voice behind the owner's 1-3
      // second delay, and nothing could tell it apart before.
      expect(voices.single.networkRequired, isTrue);
      expect(voices.single.latency, TtsVoiceLatency.veryHigh);
    });

    test('every Android quality step maps to its own value', () async {
      final voices = await _voicesFrom([
        for (final q in ['very high', 'high', 'normal', 'low', 'very low'])
          {'name': q, 'locale': 'ar-EG', 'quality': q},
      ]);

      expect(voices.map((v) => v.quality), [
        TtsVoiceQuality.veryHigh,
        TtsVoiceQuality.high,
        TtsVoiceQuality.normal,
        TtsVoiceQuality.low,
        TtsVoiceQuality.veryLow,
      ]);
    });

    test('every Android latency step maps to its own value', () async {
      final voices = await _voicesFrom([
        for (final l in ['very low', 'low', 'normal', 'high', 'very high'])
          {'name': l, 'locale': 'ar-EG', 'latency': l},
      ]);

      expect(voices.map((v) => v.latency), [
        TtsVoiceLatency.veryLow,
        TtsVoiceLatency.low,
        TtsVoiceLatency.normal,
        TtsVoiceLatency.high,
        TtsVoiceLatency.veryHigh,
      ]);
    });

    test('iOS\'s own three quality words are understood too', () async {
      // iOS reports "default"/"enhanced"/"premium" and sends no latency or
      // network field at all.
      final voices = await _voicesFrom([
        for (final q in ['premium', 'enhanced', 'default'])
          {'name': q, 'locale': 'ar-SA', 'quality': q},
      ]);

      expect(voices.map((v) => v.quality), [
        TtsVoiceQuality.veryHigh,
        TtsVoiceQuality.high,
        TtsVoiceQuality.normal,
      ]);
    });

    test(
      'a voice that describes nothing reads as unknown, on-device',
      () async {
        final voices = await _voicesFrom([
          {'name': 'bare', 'locale': 'ar-EG'},
        ]);

        expect(voices.single.quality, TtsVoiceQuality.unknown);
        expect(voices.single.latency, TtsVoiceLatency.unknown);
        // No field means on-device: that is what iOS's voices are, and
        // assuming otherwise would reject every voice on that platform.
        expect(voices.single.networkRequired, isFalse);
      },
    );

    test('an unrecognised quality or latency word reads as unknown', () async {
      final voices = await _voicesFrom([
        {
          'name': 'odd',
          'locale': 'ar-EG',
          'quality': 'superb',
          'latency': 'instant',
        },
      ]);

      expect(voices.single.quality, TtsVoiceQuality.unknown);
      expect(voices.single.latency, TtsVoiceLatency.unknown);
    });

    test('an entry with no name or no locale is dropped, not guessed at', () {
      // Without both there is nothing to select the voice by later.
      return expectLater(
        _voicesFrom([
          {'locale': 'ar-EG'},
          {'name': 'nameless'},
          {'name': 'whole', 'locale': 'ar-EG'},
        ]),
        completion([const TtsVoice(name: 'whole', locale: 'ar-EG')]),
      );
    });

    test('a platform that answers with null gives an empty list', () async {
      expect(await _voicesFrom(null), isEmpty);
    });

    test('a throw from the platform becomes a TtsFailure', () async {
      final service = FlutterTtsTextToSpeechService(
        _RecordingLogger(),
        _ThrowingFlutterTts(),
      );

      expect((await service.getVoices()).failureOrNull, isA<TtsFailure>());
    });
  });

  // F30-T04. Enumerating every voice of every installed engine is a slow
  // platform call, and it used to run on every single reading — a good part
  // of the 1-3 second delay the owner reported (F30 RC-6).
  group('FlutterTtsTextToSpeechService caches the voice list', () {
    test('the device is asked once, however many times we ask', () async {
      final tts = _CountingFlutterTts([
        {'name': 'ar-EG-local', 'locale': 'ar-EG'},
      ]);
      final service = FlutterTtsTextToSpeechService(_RecordingLogger(), tts);

      await service.getVoices();
      await service.getVoices();
      await service.getVoices();

      expect(tts.calls, 1);
    });

    test('the cached answer is the same list, not a stale empty one', () async {
      final tts = _CountingFlutterTts([
        {'name': 'ar-EG-local', 'locale': 'ar-EG', 'quality': 'high'},
      ]);
      final service = FlutterTtsTextToSpeechService(_RecordingLogger(), tts);

      final first = (await service.getVoices()).valueOrNull;
      final second = (await service.getVoices()).valueOrNull;

      expect(second, first);
      expect(second!.single.quality, TtsVoiceQuality.high);
    });

    test('forgetVoices makes the next call ask the device again', () async {
      final tts = _CountingFlutterTts([
        {'name': 'ar-EG-local', 'locale': 'ar-EG'},
      ]);
      final service = FlutterTtsTextToSpeechService(_RecordingLogger(), tts);

      await service.getVoices();
      service.forgetVoices();
      await service.getVoices();

      // F30-T07 sends a user with no Arabic voice out to install one; the
      // answer must not still be "you have none" when they come back.
      expect(tts.calls, 2);
    });

    test('an empty answer is never cached', () async {
      // Android reports no voices at all while its engine is still binding.
      // Remembering that would mean "this device has no voices" for the rest
      // of the session, which T07 would then report as a missing Arabic
      // voice on a phone that has one.
      final tts = _CountingFlutterTts(null);
      final service = FlutterTtsTextToSpeechService(_RecordingLogger(), tts);

      expect((await service.getVoices()).valueOrNull, isEmpty);
      tts.answer = [
        {'name': 'ar-EG-local', 'locale': 'ar-EG'},
      ];

      expect((await service.getVoices()).valueOrNull, hasLength(1));
      expect(tts.calls, 2);
    });

    test('a failure is not cached either', () async {
      final tts = _CountingFlutterTts(null, throws: true);
      final service = FlutterTtsTextToSpeechService(_RecordingLogger(), tts);

      expect((await service.getVoices()).failureOrNull, isA<TtsFailure>());
      tts
        ..throws = false
        ..answer = [
          {'name': 'ar-EG-local', 'locale': 'ar-EG'},
        ];

      expect((await service.getVoices()).valueOrNull, hasLength(1));
    });
  });

  group('TtsVoice', () {
    test('identity is the name and locale, not how the voice sounds', () {
      // `DefaultReadingVoiceStore` only ever persisted those two, so a voice
      // read back from storage has to equal the one the device reported.
      const reported = TtsVoice(
        name: 'ar-EG-local',
        locale: 'ar-EG',
        quality: TtsVoiceQuality.veryHigh,
        latency: TtsVoiceLatency.veryLow,
        networkRequired: true,
      );
      const stored = TtsVoice(name: 'ar-EG-local', locale: 'ar-EG');

      expect(reported, stored);
      expect(reported.hashCode, stored.hashCode);
    });

    test('a different locale is a different voice', () {
      expect(
        const TtsVoice(name: 'same', locale: 'ar-EG'),
        isNot(const TtsVoice(name: 'same', locale: 'ar-SA')),
      );
    });
  });

  group('the ranks the voice fields are ordered by', () {
    test('a higher quality rank sounds better', () {
      expect(
        TtsVoiceQuality.veryHigh.rank,
        greaterThan(TtsVoiceQuality.high.rank),
      );
      expect(TtsVoiceQuality.low.rank, lessThan(TtsVoiceQuality.normal.rank));
    });

    test('a lower latency rank starts sooner — the opposite direction', () {
      expect(
        TtsVoiceLatency.veryLow.rank,
        lessThan(TtsVoiceLatency.veryHigh.rank),
      );
    });

    test('unknown ranks level with normal, never last', () {
      // A voice on a platform that sends no such field must not lose to one
      // that reported itself as poor.
      expect(TtsVoiceQuality.unknown.rank, TtsVoiceQuality.normal.rank);
      expect(TtsVoiceLatency.unknown.rank, TtsVoiceLatency.normal.rank);
      expect(
        TtsVoiceQuality.unknown.rank,
        greaterThan(TtsVoiceQuality.low.rank),
      );
    });
  });

  // F30-T08. The handler behind every one of these used to be
  // `(_) => _events.add(const TtsFailed())`: the engine's reason was thrown
  // away, so a voice that was still downloading and an engine that was gone
  // arrived as the same unexplained failure (F30 RC-2).
  group('FlutterTtsTextToSpeechService reads the engine\'s error', () {
    test('a network error is carried through as a transient one', () async {
      final built = _reportingService();

      final failure = built.failureFrom('Error from TextToSpeech (speak) - -6');

      expect(await failure, const TtsFailed(code: TtsErrorCode.network));
      expect(TtsErrorCode.network.isTransient, isTrue);
    });

    test('a voice still downloading is transient, not a dead end', () async {
      final built = _reportingService();

      // What a phone reports the first time a freshly installed voice is
      // used — the fix is to wait a moment, not to give up.
      final failure = built.failureFrom('Error from TextToSpeech (speak) - -9');

      expect(
        await failure,
        const TtsFailed(code: TtsErrorCode.notInstalledYet),
      );
      expect(TtsErrorCode.notInstalledYet.isTransient, isTrue);
    });

    test('an engine whose service failed is permanent', () async {
      final built = _reportingService();

      final failure = built.failureFrom('Error from TextToSpeech (speak) - -4');

      expect(await failure, const TtsFailed(code: TtsErrorCode.service));
      expect(TtsErrorCode.service.isTransient, isFalse);
    });

    test('the synthesise-to-file wording is read the same way', () async {
      // Both of the plugin's error channels land on the one handler, and
      // they differ only in the word in the brackets.
      final built = _reportingService();

      final failure = built.failureFrom('Error from TextToSpeech (synth) - -5');

      expect(await failure, const TtsFailed(code: TtsErrorCode.output));
    });

    test('an error with no code at all is unknown, and retryable', () async {
      // Android's older `onError(utteranceId)` callback carries no code.
      final built = _reportingService();

      final failure = built.failureFrom('Error from TextToSpeech (speak)');

      expect((await failure as TtsFailed).code, TtsErrorCode.unknown);
      expect(TtsErrorCode.unknown.isTransient, isTrue);
    });

    test('the generic ERROR (-1) explains nothing, so it is unknown', () async {
      final built = _reportingService();

      final failure = built.failureFrom('Error from TextToSpeech (speak) - -1');

      expect((await failure as TtsFailed).code, TtsErrorCode.unknown);
    });

    test('a payload that is not a message at all is unknown', () async {
      final built = _reportingService();

      final failure = built.failureFrom(const <String, String>{});

      expect((await failure as TtsFailed).code, TtsErrorCode.unknown);
    });
  });

  // The other half of RC-2: none of this reached F27's logging, so
  // production could not see it at all.
  // F30-T09. The wrapper threw the answer away and returned `Ok`, so the
  // cubit put a mini-player over an engine that was saying nothing — and
  // with no completion event coming either, the bar stayed (F30 RC-3).
  group('FlutterTtsTextToSpeechService honours what speak() answers', () {
    test('an utterance the engine takes is a success', () async {
      final tts = _SpeakingFlutterTts(answer: 1);
      final service = FlutterTtsTextToSpeechService(_RecordingLogger(), tts);

      expect((await service.speak('ورقة')).failureOrNull, isNull);
      expect(tts.spoken, ['ورقة']);
    });

    test('an utterance the engine declines is a failure, not a silent '
        'success', () async {
      // `0` is iOS's answer when a paused synthesizer will not continue.
      final service = FlutterTtsTextToSpeechService(
        _RecordingLogger(),
        _SpeakingFlutterTts(answer: 0),
      );

      expect((await service.speak('ورقة')).failureOrNull, isA<TtsFailure>());
    });

    test(
      'an answer that is not one of the engine\'s own is not trusted',
      () async {
        final service = FlutterTtsTextToSpeechService(
          _RecordingLogger(),
          _SpeakingFlutterTts(answer: null),
        );

        expect((await service.speak('ورقة')).failureOrNull, isA<TtsFailure>());
      },
    );

    test('a declined utterance leaves nothing for resume to replay', () async {
      // Otherwise «استكمال القراءة» would replay a reading that never
      // started.
      final tts = _SpeakingFlutterTts(answer: 0);
      final service = FlutterTtsTextToSpeechService(_RecordingLogger(), tts);

      await service.speak('ورقة');
      final resumed = await service.resume();

      expect(resumed.failureOrNull, isNull);
      expect(tts.spoken, ['ورقة']);
    });

    test('a refusal is logged, so production can see a reading that never '
        'started', () async {
      final logger = _RecordingLogger();
      final service = FlutterTtsTextToSpeechService(
        logger,
        _SpeakingFlutterTts(answer: 0),
      );

      await service.speak('ورقة');

      expect(logger.codes, ['TTS']);
    });

    // On Android a refusal is not an answer at all: the plugin parks the
    // call and re-runs it on the next engine initialisation, which for a
    // native `speak()` that failed outright — text over
    // `getMaxSpeechInputLength` — never comes.
    testWidgets('a call the engine never answers is reported once the '
        'bound passes', (tester) async {
      final service = FlutterTtsTextToSpeechService(
        _RecordingLogger(),
        _SpeakingFlutterTts.silent(),
      );

      Result<void, AppFailure>? outcome;
      unawaited(service.speak('ورقة').then((result) => outcome = result));
      await tester.pump(const Duration(seconds: 4));
      expect(outcome, isNull, reason: 'a slow engine is waited out, not cut');

      await tester.pump(const Duration(seconds: 2));

      expect(outcome?.failureOrNull, isA<TtsFailure>());
    });
  });

  group('FlutterTtsTextToSpeechService logs the engine\'s error', () {
    test('the classified code is recorded, never the message', () async {
      final built = _reportingService();

      await built.failureFrom('Error from TextToSpeech (speak) - -7');

      expect(built.logger.codes, ['TTS_NETWORK_TIMEOUT']);
    });

    test('a permanent error is logged as the failure it becomes', () async {
      final built = _reportingService();

      await built.failureFrom('Error from TextToSpeech (speak) - -8');

      expect(
        built.logger.events.single.failure,
        const TtsEngineUnavailableFailure(TtsErrorCode.invalidRequest),
      );
    });

    test('a transient error is logged as the retryable failure', () async {
      final built = _reportingService();

      await built.failureFrom('Error from TextToSpeech (speak) - -6');

      expect(
        built.logger.events.single.failure,
        const TtsFailure(TtsErrorCode.network),
      );
    });
  });
}

/// The parsed voices the service reports when the platform answers [raw].
Future<List<TtsVoice>> _voicesFrom(Object? raw) async {
  final service = FlutterTtsTextToSpeechService(
    _RecordingLogger(),
    _FakeFlutterTts(raw),
  );
  final outcome = await service.getVoices();
  return outcome.valueOrNull ??
      (throw StateError('getVoices failed: $outcome'));
}

/// `FlutterTts` with only the one getter the service reads replaced — the
/// handler setters its constructor calls are the real, harmless ones.
final class _FakeFlutterTts extends ft.FlutterTts {
  _FakeFlutterTts(this._raw);

  final Object? _raw;

  @override
  Future<dynamic> get getVoices async => _raw;
}

final class _ThrowingFlutterTts extends ft.FlutterTts {
  @override
  Future<dynamic> get getVoices async => throw Exception('no engine');
}

/// Counts how often the platform is actually asked, so the cache can be
/// measured rather than assumed, and lets the answer change between calls.
final class _CountingFlutterTts extends ft.FlutterTts {
  _CountingFlutterTts(this.answer, {this.throws = false});

  Object? answer;
  bool throws;
  int calls = 0;

  @override
  Future<dynamic> get getVoices async {
    calls++;
    if (throws) throw Exception('no engine');
    return answer;
  }
}

/// A service whose engine can be made to report an error, with the log it
/// writes to kept alongside it (F30-T08).
({
  _RecordingLogger logger,
  _ErroringFlutterTts tts,
  TextToSpeechService service,
})
_reportingService() {
  final logger = _RecordingLogger();
  final tts = _ErroringFlutterTts();
  return (
    logger: logger,
    tts: tts,
    service: FlutterTtsTextToSpeechService(logger, tts),
  );
}

extension
    on
        ({
          _RecordingLogger logger,
          _ErroringFlutterTts tts,
          TextToSpeechService service,
        }) {
  /// The event the service emits when the engine reports [payload].
  ///
  /// The stream is listened to before the error is reported, since
  /// `events` is a broadcast stream and would otherwise drop it.
  Future<TtsEvent> failureFrom(Object? payload) {
    final emitted = service.events.first;
    tts.reportError(payload);
    return emitted;
  }
}

/// `FlutterTts` that reports an error on demand, through the very handler
/// the service registered on it.
final class _ErroringFlutterTts extends ft.FlutterTts {
  void reportError(Object? payload) => errorHandler!(payload);
}

final class _RecordingLogger implements AppLogger {
  final List<LogEvent> events = [];

  @override
  void event(LogEvent e) => events.add(e);

  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) =>
      events.add(LogEvent(failure: failure, stage: stage));

  List<String?> get codes =>
      events.map((e) => e.toLogMap()['errorCode'] as String?).toList();
}

/// `FlutterTts` whose `speak` answers however the test needs it to — or,
/// [_SpeakingFlutterTts.silent], never answers at all, the way the Android
/// plugin leaves a parked call.
final class _SpeakingFlutterTts extends ft.FlutterTts {
  _SpeakingFlutterTts({required Object? answer})
    : _answer = answer,
      _answers = true;

  _SpeakingFlutterTts.silent() : _answer = null, _answers = false;

  final Object? _answer;

  /// Whether the platform answers at all — false is the parked call.
  final bool _answers;
  final List<String> spoken = [];

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    spoken.add(text);
    return _answers
        ? Future<Object?>.value(_answer)
        : Completer<Object?>().future;
  }
}
