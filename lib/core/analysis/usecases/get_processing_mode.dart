import '../processing_mode.dart';
import '../processing_mode_store.dart';

/// Reads the user's preferred paper processing method (F11-T03) — defaults
/// to [ProcessingMode.smartAnalysis], matching the app's primary purpose,
/// until the user explicitly switches to text-only.
final class GetProcessingMode {
  const GetProcessingMode(this._store);

  final ProcessingModeStore _store;

  Future<ProcessingMode> call() async =>
      await _store.readMode() ?? ProcessingMode.smartAnalysis;
}
