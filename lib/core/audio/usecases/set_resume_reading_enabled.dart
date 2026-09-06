import '../resume_reading_enabled_store.dart';

/// Persists the user's choice for «استكمال القراءة من آخر مكان» (F11-T07).
final class SetResumeReadingEnabled {
  const SetResumeReadingEnabled(this._store);

  final ResumeReadingEnabledStore _store;

  Future<void> call(bool enabled) => _store.writeEnabled(enabled);
}
