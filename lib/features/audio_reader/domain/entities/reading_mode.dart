/// How much of a result `BuildReadingText` turns into speech (F10-T02).
///
/// Each mode is a self-contained utterance, not a layer stacked on the one
/// before it in the UI sense — the mini-player (F10-T03) offers all four and
/// switching modes restarts the reading rather than continuing it.
enum ReadingMode {
  /// Just the one-line «الخلاصة السريعة».
  summaryOnly,

  /// The summary, then every labelled fact from «أهم المعلومات» — same
  /// wording and caveats the key-information card shows.
  summaryAndKeyInformation,

  /// The full narrated explanation — «الشرح التفصيلي» — already written to
  /// stand on its own (`AnalysisSummary.detailed`).
  fullExplanation,

  /// The raw OCR text, exactly as extracted — nothing summarised.
  extractedText,
}
