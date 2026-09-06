/// The blocks the result screen is made of, in the order the master plan
/// (§4, «ترتيب شاشة النتيجة») fixes them.
///
/// Declaration order **is** display order: `BuildAnalysisResult` filters this
/// list rather than assembling one of its own, so a section can never drift
/// out of place — and a new section has to be inserted at the position it is
/// meant to appear.
///
/// Pure Dart, no Flutter import.
enum AnalysisSection {
  /// What the paper is: document type and title. Always shown — the user has
  /// to know what they are looking at even when nothing else was understood.
  header,

  /// The one-line «الخلاصة السريعة».
  summary,

  /// «المطلوب منك» — what the user has to do about this paper.
  actionRequired,

  /// Medical / legal / government disclaimers.
  ///
  /// Sits above the details on purpose: a caution the user must read before
  /// acting on any figure below it.
  warnings,

  /// The labelled facts read off the paper — «المعلومات المهمة».
  keyInformation,

  /// Money figures. §4 counts these among the key information; they get their
  /// own block, immediately after it, because they carry a currency and their
  /// own confidence and read badly as plain rows.
  amounts,

  /// «التواريخ والمواعيد», the branch point into a reminder.
  dates,

  /// Papers to bring along — «المستندات المطلوبة».
  requiredDocuments,

  /// Step-by-step guidance. Follows the documents block for the same reason
  /// §4 puts that block late: both are about the trip the user is about to
  /// make, not about reading the paper.
  instructions,

  /// The full explanation — «الشرح التفصيلي».
  detailedExplanation,

  /// The original OCR text. Last, and never omitted while there is text:
  /// UX rule §5.12 — the extracted text stays available for review.
  extractedText,
}
