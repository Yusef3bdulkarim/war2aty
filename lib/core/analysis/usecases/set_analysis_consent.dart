import '../analysis_consent_store.dart';

/// Persists the user's choice for «السماح بإرسال النص للتحليل» (F11-T02).
final class SetAnalysisConsent {
  const SetAnalysisConsent(this._store);

  final AnalysisConsentStore _store;

  Future<void> call(bool consent) => _store.writeConsent(consent);
}
