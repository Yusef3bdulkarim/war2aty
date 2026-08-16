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
}
