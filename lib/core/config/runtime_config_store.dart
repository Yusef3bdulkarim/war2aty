import 'runtime_config.dart';

/// Holds the config that is active for this app session.
///
/// Loaded once during launch, then read by whoever needs a limit or flag
/// (usage quota, OCR cap, analysis timeout). Starts at [RuntimeConfig.defaults]
/// so every reader has a sane value even before — or without — a successful
/// load.
final class RuntimeConfigStore {
  RuntimeConfig _current = RuntimeConfig.defaults;

  RuntimeConfig get current => _current;

  /// Replaces the active config. Called only by the launch config step (and
  /// tests) — a named method keeps every mutation intentional and greppable.
  void update(RuntimeConfig config) => _current = config;
}
