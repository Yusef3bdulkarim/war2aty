import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart' as ft;
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/audio_reader/data/services/flutter_tts_text_to_speech_service.dart';

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
      final service = FlutterTtsTextToSpeechService(_ThrowingFlutterTts());

      expect((await service.getVoices()).failureOrNull, isA<TtsFailure>());
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
}

/// The parsed voices the service reports when the platform answers [raw].
Future<List<TtsVoice>> _voicesFrom(Object? raw) async {
  final service = FlutterTtsTextToSpeechService(_FakeFlutterTts(raw));
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
