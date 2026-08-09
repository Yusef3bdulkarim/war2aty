/// What the router hands the create-from-document screen (F09-T03) — the
/// date the user picked (`chooseReminderDate`, F09-T07) plus enough of the
/// document to prefill the form and show the link back to it.
final class ReminderFromDocumentArgs {
  const ReminderFromDocumentArgs({
    this.documentId,
    this.documentTitle,
    required this.title,
    required this.eventDate,
    this.eventMinuteOfDay,
  });

  /// Set only when the reminder was started from an already-saved document's
  /// details screen — a reminder from a fresh, not-yet-saved result has
  /// nothing to link back to.
  final String? documentId;
  final String? documentTitle;

  /// Prefilled into the title field — the document's own title, editable
  /// from there.
  final String title;

  final DateTime eventDate;

  /// `null` when the paper gave a day but no hour (F09-T06).
  final int? eventMinuteOfDay;
}
