import '../../../core/localization/app_strings.dart';
import '../domain/entities/document_kind.dart';

/// What to call [kind] on screen.
///
/// A function rather than an extension on the enum: [DocumentKind] lives in the
/// domain, which must not reach for localization (or anything else outside
/// itself).
String documentKindLabel(AppStrings strings, DocumentKind kind) =>
    switch (kind) {
      DocumentKind.invoice => strings.documentKindInvoice,
      DocumentKind.receipt => strings.documentKindReceipt,
      DocumentKind.appointment => strings.documentKindAppointment,
      DocumentKind.government => strings.documentKindGovernment,
      DocumentKind.exam => strings.documentKindExam,
      DocumentKind.medical => strings.documentKindMedical,
      DocumentKind.legal => strings.documentKindLegal,
      DocumentKind.financial => strings.documentKindFinancial,
      DocumentKind.educational => strings.documentKindEducational,
      DocumentKind.other => strings.documentKindOther,
    };
