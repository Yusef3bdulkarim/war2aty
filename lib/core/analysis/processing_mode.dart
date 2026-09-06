/// How captured papers are processed (F11-T03).
///
/// The user picks one on the settings screen; the analysis flow reads it
/// before deciding whether to call the backend or stop after OCR.
///
/// The enum values double as the `app_settings` table's persisted strings —
/// [name] is written and matched on read — so they must not be renamed
/// without a migration.
enum ProcessingMode {
  /// OCR + AI analysis via the Edge Function. The default.
  smartAnalysis,

  /// OCR only — no text leaves the phone, no network call.
  textOnly,
}
