import '../../../../core/error/app_failure.dart';

/// States of the «حفظ الورقة» action on the result screen.
sealed class SaveDocumentState {
  const SaveDocumentState();
}

/// Nothing saved yet; the button is live.
final class SaveDocumentIdle extends SaveDocumentState {
  const SaveDocumentIdle();
}

/// The write is in flight. The button is disabled so one tap cannot become
/// two documents.
final class SaveDocumentSaving extends SaveDocumentState {
  const SaveDocumentSaving();
}

/// The paper is on the device. [documentId] is what F09 links a reminder to.
final class SaveDocumentSaved extends SaveDocumentState {
  const SaveDocumentSaved(this.documentId);

  final String documentId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveDocumentSaved && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;
}

/// The write failed. [failure] is carried rather than a message so the screen
/// picks the Arabic copy — the layer that owns wording (CLAUDE.md §B5).
final class SaveDocumentFailed extends SaveDocumentState {
  const SaveDocumentFailed(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveDocumentFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
