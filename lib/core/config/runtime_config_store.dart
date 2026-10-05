import 'runtime_config.dart';

/// Holds the config that is active for this app session.
///
/// Loaded once just after launch — the fetch is the app's first HTTPS request
/// and blocked the splash animation, so it waits until the first screen is up
/// (F27-P01) — then read by whoever needs a limit or flag (usage quota, OCR
/// cap, analysis timeout). Starts at [RuntimeConfig.defaults] so every reader
/// has a sane value before, during, or without a successful load.
final class RuntimeConfigStore {
  RuntimeConfig _current = RuntimeConfig.defaults;

  RuntimeConfig get current => _current;

  /// Replaces the active config. Called only by the launch config step (and
  /// tests) — a named method keeps every mutation intentional and greppable.
  void update(RuntimeConfig config) => _current = config;
}
