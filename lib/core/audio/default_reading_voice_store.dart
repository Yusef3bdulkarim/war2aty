import '../database/app_database.dart';
import 'tts_voice.dart';

/// Persists the user's «صوت القراءة» choice (F11-T07) — a specific device
/// [TtsVoice] every reading should use instead of `SelectVoiceForReading`'s
/// automatic script match.
abstract interface class DefaultReadingVoiceStore {
  /// `null` means «الصوت الافتراضي» — either the user never touched the
  /// setting, or explicitly picked it to go back to the automatic match.
  Future<TtsVoice?> readVoice();

  /// `null` resets the choice back to «الصوت الافتراضي».
  Future<void> writeVoice(TtsVoice? voice);
}

/// [DefaultReadingVoiceStore] backed by the Drift `app_settings` table — the
/// same key/value table every other core store uses.
///
/// A [TtsVoice] has two fields, so it takes two keys rather than packing them
/// into one string with a delimiter a device-reported name could plausibly
/// contain itself.
final class DriftDefaultReadingVoiceStore implements DefaultReadingVoiceStore {
  const DriftDefaultReadingVoiceStore(this._db);

  static const String _nameKey = 'default_reading_voice_name';
  static const String _localeKey = 'default_reading_voice_locale';

  final AppDatabase _db;

  @override
  Future<TtsVoice?> readVoice() async {
    final name = await _db.getSetting(_nameKey);
    final locale = await _db.getSetting(_localeKey);
    if (name == null || locale == null) return null;
    return TtsVoice(name: name, locale: locale);
  }

  @override
  Future<void> writeVoice(TtsVoice? voice) async {
    if (voice == null) {
      await _db.deleteSetting(_nameKey);
      await _db.deleteSetting(_localeKey);
      return;
    }
    await _db.setSetting(_nameKey, voice.name);
    await _db.setSetting(_localeKey, voice.locale);
  }
}
