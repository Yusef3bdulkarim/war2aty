import '../resume_reading_enabled_store.dart';

/// Reads the user's «استكمال القراءة من آخر مكان» preference (F11-T07) —
/// defaults to `true`, matching the approved design's own initial state,
/// until the user explicitly turns it off.
final class GetResumeReadingEnabled {
  const GetResumeReadingEnabled(this._store);

  final ResumeReadingEnabledStore _store;

  Future<bool> call() async => await _store.readEnabled() ?? true;
}
