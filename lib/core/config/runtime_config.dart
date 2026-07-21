/// Runtime-tunable configuration (master plan §52).
///
/// Every value can be changed from the backend without shipping a new app
/// build — to pause analysis, adjust the daily limit, cap OCR size, block an
/// old version, or show a maintenance notice. Until the backend lands (M4) the
/// app runs on [defaults].
final class RuntimeConfig {
  const RuntimeConfig({
    required this.analysisEnabled,
    required this.dailyAnalysisLimit,
    required this.maxOcrCharacters,
    required this.analysisTimeout,
    required this.schemaVersion,
    required this.minimumAppVersion,
    this.maintenanceMessage,
  });

  /// Local fallback values. Conservative and safe to ship.
  static const RuntimeConfig defaults = RuntimeConfig(
    analysisEnabled: true,
    // Locked product decision: 3 successful analyses per Africa/Cairo day.
    dailyAnalysisLimit: 3,
    // Caps the payload sent to the analysis function; a page of OCR text is
    // far smaller than this.
    maxOcrCharacters: 12000,
    analysisTimeout: Duration(seconds: 30),
    schemaVersion: '1.0',
    minimumAppVersion: '1.0.0',
  );

  final bool analysisEnabled;
  final int dailyAnalysisLimit;
  final int maxOcrCharacters;
  final Duration analysisTimeout;
  final String schemaVersion;
  final String minimumAppVersion;

  /// Shown to the user when set; `null` means normal operation.
  final String? maintenanceMessage;

  @override
  bool operator ==(Object other) =>
      other is RuntimeConfig &&
      other.analysisEnabled == analysisEnabled &&
      other.dailyAnalysisLimit == dailyAnalysisLimit &&
      other.maxOcrCharacters == maxOcrCharacters &&
      other.analysisTimeout == analysisTimeout &&
      other.schemaVersion == schemaVersion &&
      other.minimumAppVersion == minimumAppVersion &&
      other.maintenanceMessage == maintenanceMessage;

  @override
  int get hashCode => Object.hash(
    analysisEnabled,
    dailyAnalysisLimit,
    maxOcrCharacters,
    analysisTimeout,
    schemaVersion,
    minimumAppVersion,
    maintenanceMessage,
  );
}
