import 'document_category.dart';

/// The kind of paper the analysis recognised — API_CONTRACT §30.1.
///
/// Finer-grained than [DocumentCategory]: this drives the result screen's
/// wording and its warning defaults, while the category drives Home's recent
/// strip and the documents-list filters.
enum DocumentKind {
  /// Utility bill, telecom bill, subscription invoice.
  invoice,

  /// Payment receipt, purchase receipt.
  receipt,

  /// Medical appointment, official meeting, reservation.
  appointment,

  /// Government letter, official notice, tax notice.
  government,

  /// Exam result, grade report, certificate.
  exam,

  /// Medical report, lab result, prescription.
  medical,

  /// Legal document, contract, court notice.
  legal,

  /// Bank statement, insurance document.
  financial,

  /// School notice, university letter, enrollment.
  educational,

  /// Anything that doesn't fit the above.
  other,
}

extension DocumentKindCategory on DocumentKind {
  /// The coarse [DocumentCategory] this kind files under.
  ///
  /// Only the four categories Home and the documents list can filter by have a
  /// direct counterpart; medical, legal and financial papers have no category
  /// of their own in the MVP and fall to [DocumentCategory.other] rather than
  /// being forced into a nearby one.
  DocumentCategory get category => switch (this) {
    DocumentKind.invoice || DocumentKind.receipt => DocumentCategory.invoice,
    DocumentKind.appointment => DocumentCategory.appointment,
    DocumentKind.government => DocumentCategory.government,
    DocumentKind.exam || DocumentKind.educational => DocumentCategory.education,
    DocumentKind.medical ||
    DocumentKind.legal ||
    DocumentKind.financial ||
    DocumentKind.other => DocumentCategory.other,
  };
}
