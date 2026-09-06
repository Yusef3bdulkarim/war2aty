/// A text-to-speech voice available on the device.
///
/// Mirrors the two fields every platform `flutter_tts` reports consistently
/// — `name` and `locale` — and drops the extra iOS-only fields (quality,
/// gender, identifier) the app has no use for: F10-T07 only needs "صوت
/// القراءة" picked from the device's own voices, not to rank them.
final class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  final String name;
  final String locale;

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);

  @override
  String toString() => 'TtsVoice($name, $locale)';
}
