import '../analysis_consent_store.dart';

/// Reads whether the user allows extracted text to be sent for smart
/// analysis (F11-T02) — defaults **on**, matching the design's toggle, until
/// the user explicitly turns it off. Extraction (OCR) itself never depends on
/// this: it always happens on-device either way.
final class GetAnalysisConsent {
  const GetAnalysisConsent(this._store);

  final AnalysisConsentStore _store;

  Future<bool> call() async => await _store.readConsent() ?? true;
}
