import '../processing_mode.dart';
import '../processing_mode_store.dart';

/// Persists the user's choice for «طريقة معالجة الأوراق» (F11-T03).
final class SetProcessingMode {
  const SetProcessingMode(this._store);

  final ProcessingModeStore _store;

  Future<void> call(ProcessingMode mode) => _store.writeMode(mode);
}
