import '../../../../core/audio/tts_voice.dart';

/// Picks which of the device's [TtsVoice]s should read a piece of text aloud
/// (F10-T07).
///
/// There is no on-screen picker for this yet — the design puts the voice
/// picker on the Settings screen (F11-T07), which depends on this feature
/// for its "audio prefs" but has not been built. Until then, [StartReading]
/// uses this to keep the *default* voice at least matching what is being
/// read, rather than leaving it at whatever the engine was last set to.
///
/// A device is free to have voices installed for only some locales, so this
/// never assumes an Arabic or an English one exists: it matches [text]'s own
/// dominant script to whichever installed voice's locale starts with the
/// same language code (`ar`/`en`), and returns `null` — rather than guess —
/// when nothing matches.
final class SelectVoiceForReading {
  const SelectVoiceForReading();

  TtsVoice? call(String text, List<TtsVoice> voices) {
    if (voices.isEmpty) return null;
    final languageCode = _dominantScript(text);
    for (final voice in voices) {
      if (voice.locale.toLowerCase().startsWith(languageCode)) return voice;
    }
    return null;
  }

  /// `ar` if [text] has at least as many Arabic-script letters as Latin
  /// ones, `en` otherwise. A mixed document (project context: papers may be
  /// "Arabic/English/mixed") is judged by whichever script actually
  /// dominates the text being read, not the whole document — and ties
  /// (including no letters at all, e.g. a purely numeric reading) fall to
  /// Arabic, the app's primary language.
  String _dominantScript(String text) {
    final arabic = _arabicLetters.allMatches(text).length;
    final latin = _latinLetters.allMatches(text).length;
    return arabic >= latin ? 'ar' : 'en';
  }
}

/// The Arabic and Arabic Supplement Unicode blocks, `U+0600`-`U+06FF` and
/// `U+0750`-`U+077F` — covers the letters Egyptian documents are written in.
final _arabicLetters = RegExp('[؀-ۿݐ-ݿ]');
final _latinLetters = RegExp('[A-Za-z]');
