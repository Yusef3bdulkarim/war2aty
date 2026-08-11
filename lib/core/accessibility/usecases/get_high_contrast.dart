import '../high_contrast_store.dart';

/// Reads whether «تباين عالي» is on (F11-T06) — defaults **off**, matching
/// the design's toggle, until the user explicitly turns it on.
final class GetHighContrast {
  const GetHighContrast(this._store);

  final HighContrastStore _store;

  Future<bool> call() async => await _store.readEnabled() ?? false;
}
