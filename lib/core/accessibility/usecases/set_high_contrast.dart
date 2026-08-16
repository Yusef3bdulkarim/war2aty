import '../high_contrast_store.dart';

/// Persists the user's choice for «تباين عالي» (F11-T06).
final class SetHighContrast {
  const SetHighContrast(this._store);

  final HighContrastStore _store;

  Future<void> call(bool enabled) => _store.writeEnabled(enabled);
}
