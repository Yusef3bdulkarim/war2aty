import '../default_reading_speed_store.dart';
import '../reading_speed.dart';

/// Reads the user's preferred default reading speed (F11-T07) — defaults to
/// [ReadingSpeed.normal], the same default a fresh reading already starts at
/// (F10), until the user explicitly picks another one from Settings.
final class GetDefaultReadingSpeed {
  const GetDefaultReadingSpeed(this._store);

  final DefaultReadingSpeedStore _store;

  Future<ReadingSpeed> call() async =>
      await _store.readSpeed() ?? ReadingSpeed.normal;
}
