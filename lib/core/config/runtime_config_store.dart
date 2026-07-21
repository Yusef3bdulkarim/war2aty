import 'runtime_config.dart';

/// Holds the config that is active for this app session.
///
/// Loaded once during launch, then read by whoever needs a limit or flag
/// (usage quota, OCR cap, analysis timeout). Starts at [RuntimeConfig.defaults]
/// so every reader has a sane value even before — or without — a successful
/// load.
final class RuntimeConfigStore {
  RuntimeConfig current = RuntimeConfig.defaults;
}
