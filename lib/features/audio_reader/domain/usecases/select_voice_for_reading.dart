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
/// dominant script to the installed voices whose locale starts with the same
/// language code (`ar`/`en`), and returns `null` — rather than guess — when
/// nothing matches.
///
/// Among the voices that *do* match it picks the best rather than the first
/// (F30-T05). Taking the first was most of why readings took 1–3 seconds to
/// start: the device commonly lists a network-synthesised voice ahead of an
/// on-device one, and nothing here could tell them apart until F30-T03 kept
/// the fields that say so. See [_isBetterThan] for the order.
final class SelectVoiceForReading {
  const SelectVoiceForReading();

  TtsVoice? call(String text, List<TtsVoice> voices) {
    final languageCode = _dominantScript(text);
    TtsVoice? best;
    for (final voice in voices) {
      if (!voice.locale.toLowerCase().startsWith(languageCode)) continue;
      if (best == null || _isBetterThan(voice, best)) best = voice;
    }
    return best;
  }

  /// Whether [candidate] is a better voice to read with than [incumbent]
  /// (F30-T05), in this order:
  ///
  /// 1. **On-device beats network.** A network voice has to fetch its audio
  ///    before it can make a sound, which is the bulk of the 1–3 second delay
  ///    the owner reported (F30 RC-6) and the source of the `ERROR_NETWORK`
  ///    failures behind RC-2. It also means the text being read leaves the
  ///    phone, so this is the preference that let the privacy screen stay as
  ///    it is (F30 locked decision 9). It outranks everything below: a plain
  ///    voice that speaks now beats a beautiful one that speaks in two
  ///    seconds, or not at all on a bad connection.
  /// 2. **Sooner beats later** — [TtsVoiceLatency] ranks the other way up, so
  ///    this compares for *less*.
  /// 3. **Better-sounding beats worse**, once nothing above separates them.
  ///
  /// Strictly better, never merely equal, so voices the device reports as
  /// indistinguishable keep the order it listed them in rather than the last
  /// one quietly winning.
  bool _isBetterThan(TtsVoice candidate, TtsVoice incumbent) {
    if (candidate.networkRequired != incumbent.networkRequired) {
      return !candidate.networkRequired;
    }
    if (candidate.latency.rank != incumbent.latency.rank) {
      return candidate.latency.rank < incumbent.latency.rank;
    }
    return candidate.quality.rank > incumbent.quality.rank;
  }

  /// The language code a voice for [text] has to be in — public since
  /// F30-T07, which needs to know *which* language was missing when nothing
  /// matched: Arabic has no fallback and has to be reported to the user,
  /// while English falls back to transliteration (F30 locked decisions 3 and
  /// 4).
  String languageFor(String text) => _dominantScript(text);

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
