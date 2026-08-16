import '../default_reading_speed_store.dart';
import '../reading_speed.dart';

/// Persists the user's choice for «سرعة القراءة الافتراضية» (F11-T07).
final class SetDefaultReadingSpeed {
  const SetDefaultReadingSpeed(this._store);

  final DefaultReadingSpeedStore _store;

  Future<void> call(ReadingSpeed speed) => _store.writeSpeed(speed);
}
