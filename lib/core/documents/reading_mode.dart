/// How much of a result `BuildReadingText` turns into speech (F10-T02).
///
/// Each mode is a self-contained utterance, not a layer stacked on the one
/// before it in the UI sense — switching modes restarts the reading rather
/// than continuing it. The result page's mini-player (F10-T03) offers the
/// first three as a choice; [extractedText] has no analysis to summarise, so
/// it is only reached by reading a fallback screen's text straight away,
/// never picked from a sheet.
enum ReadingMode {
  /// Just the one-line «الخلاصة السريعة».
  summaryOnly,

  /// The summary, then every labelled fact from «أهم المعلومات» — same
  /// wording and caveats the key-information card shows.
  summaryAndKeyInformation,

  /// The full narrated explanation — «الشرح التفصيلي» — already written to
  /// stand on its own (`AnalysisSummary.detailed`).
  fullExplanation,

  /// Everything on the result screen, narrated in section order: title,
  /// summary, actions, warnings, key information, amounts, dates, required
  /// documents, instructions, detailed explanation, and extracted text — only
  /// sections present in the result are read.
  readAll,

  /// The raw OCR text, exactly as extracted — nothing summarised.
  extractedText,
}
