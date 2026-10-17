import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';

const _select = SelectVoiceForReading();

const _arabicVoice = TtsVoice(name: 'Maged', locale: 'ar-EG');
const _englishVoice = TtsVoice(name: 'Samantha', locale: 'en-US');

void main() {
  group('SelectVoiceForReading', () {
    test('picks the Arabic voice for Arabic text', () {
      final voice = _select('فاتورة كهرباء لازم تتدفع.', [
        _englishVoice,
        _arabicVoice,
      ]);

      expect(voice, _arabicVoice);
    });

    test('picks the English voice for English text', () {
      final voice = _select('The bill is due on the 15th.', [
        _arabicVoice,
        _englishVoice,
      ]);

      expect(voice, _englishVoice);
    });

    test('judges a mixed text by whichever script dominates it', () {
      // Mostly Arabic with one English word — Arabic wins.
      final voice = _select('فاتورة كهرباء invoice لازم تتدفع قبل الموعد.', [
        _englishVoice,
        _arabicVoice,
      ]);

      expect(voice, _arabicVoice);
    });

    test('returns null when no installed voice matches the locale', () {
      final voice = _select('فاتورة كهرباء', [_englishVoice]);

      expect(voice, isNull);
    });

    test('returns null when the device has no voices at all', () {
      final voice = _select('فاتورة كهرباء', const []);

      expect(voice, isNull);
    });

    test('matches the locale prefix case-insensitively', () {
      const upperCaseLocale = TtsVoice(name: 'Maged', locale: 'AR-EG');

      final voice = _select('فاتورة كهرباء', [upperCaseLocale]);

      expect(voice, upperCaseLocale);
    });

    test('falls back to Arabic for text with no letters at all', () {
      final voice = _select('١٢٣ - 2026/04/15', [_englishVoice, _arabicVoice]);

      expect(voice, _arabicVoice);
    });
  });

  // F30-T05. Taking the first matching voice is most of why a reading took
  // 1-3 seconds to start: devices commonly list a network-synthesised voice
  // ahead of an on-device one, and until T03 nothing here could tell them
  // apart.
  group('SelectVoiceForReading · which matching voice', () {
    const network = TtsVoice(
      name: 'ar-EG-network',
      locale: 'ar-EG',
      quality: TtsVoiceQuality.veryHigh,
      latency: TtsVoiceLatency.veryHigh,
      networkRequired: true,
    );
    const onDevice = TtsVoice(
      name: 'ar-EG-local',
      locale: 'ar-EG',
      quality: TtsVoiceQuality.low,
      latency: TtsVoiceLatency.normal,
    );

    test('an on-device voice wins even when listed second', () {
      expect(_select('فاتورة كهرباء', [network, onDevice]), onDevice);
    });

    test('an on-device voice wins even when it sounds worse', () {
      // The network voice here is very high quality and the local one low.
      // A plain voice that speaks now still beats a beautiful one that
      // speaks in two seconds — or not at all on a bad connection.
      expect(onDevice.quality.rank, lessThan(network.quality.rank));
      expect(_select('فاتورة كهرباء', [network, onDevice]), onDevice);
    });

    test('a network voice is still used when it is the only match', () {
      // Refusing to read at all would be worse than reading slowly.
      expect(_select('فاتورة كهرباء', [network]), network);
    });

    test('among on-device voices, the one that starts soonest wins', () {
      const slower = TtsVoice(
        name: 'ar-EG-slower',
        locale: 'ar-EG',
        latency: TtsVoiceLatency.high,
        quality: TtsVoiceQuality.veryHigh,
      );
      const sooner = TtsVoice(
        name: 'ar-EG-sooner',
        locale: 'ar-EG',
        latency: TtsVoiceLatency.veryLow,
        quality: TtsVoiceQuality.low,
      );

      expect(_select('فاتورة كهرباء', [slower, sooner]), sooner);
    });

    test('quality decides only once network and latency tie', () {
      const worse = TtsVoice(
        name: 'ar-EG-worse',
        locale: 'ar-EG',
        latency: TtsVoiceLatency.low,
        quality: TtsVoiceQuality.normal,
      );
      const better = TtsVoice(
        name: 'ar-EG-better',
        locale: 'ar-EG',
        latency: TtsVoiceLatency.low,
        quality: TtsVoiceQuality.veryHigh,
      );

      expect(_select('فاتورة كهرباء', [worse, better]), better);
    });

    test('voices the device cannot tell apart keep its own order', () {
      const first = TtsVoice(name: 'ar-EG-first', locale: 'ar-EG');
      const second = TtsVoice(name: 'ar-EG-second', locale: 'ar-EG');

      expect(_select('فاتورة كهرباء', [first, second])?.name, 'ar-EG-first');
    });

    test('a better voice in the wrong language is still not chosen', () {
      const greatEnglish = TtsVoice(
        name: 'en-US-great',
        locale: 'en-US',
        quality: TtsVoiceQuality.veryHigh,
        latency: TtsVoiceLatency.veryLow,
      );

      expect(_select('فاتورة كهرباء', [greatEnglish, network]), network);
    });

    test('no voice in the text\'s language still gives null', () {
      expect(_select('فاتورة كهرباء', [_englishVoice]), isNull);
    });
  });
}
