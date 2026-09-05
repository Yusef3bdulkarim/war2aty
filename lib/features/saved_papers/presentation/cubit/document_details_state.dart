import 'dart:typed_data';

import '../../../../core/documents/analysis_section.dart';
import '../../../../core/documents/saved_document.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/list_equality.dart';

/// State of the document details screen (F08-T08).
sealed class DocumentDetailsState {
  const DocumentDetailsState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No document has arrived from the database yet.
final class DocumentDetailsLoading extends DocumentDetailsState {
  const DocumentDetailsLoading();
}

/// The document, with [sections] ordered and filtered the same way the
/// result screen's are — a saved paper reads exactly as it did before it was
/// saved.
final class DocumentDetailsAvailable extends DocumentDetailsState {
  const DocumentDetailsAvailable({
    required this.document,
    required this.sections,
    this.imageBytes,
  });

  final SavedDocument document;
  final List<AnalysisSection> sections;

  /// The decrypted picture of the original paper, or `null` when the document
  /// was saved without its image, or the image is still loading / failed to
  /// decrypt. Progressive: the document shows immediately; the image appears
  /// once decryption finishes.
  final Uint8List? imageBytes;

  @override
  bool operator ==(Object other) =>
      other is DocumentDetailsAvailable &&
      other.document == document &&
      listEquals(other.sections, sections) &&
      _bytesEqual(other.imageBytes, imageBytes);

  @override
  int get hashCode => Object.hash(
    document,
    Object.hashAll(sections),
    imageBytes == null ? null : Object.hashAll(imageBytes!),
  );
}

bool _bytesEqual(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The document is gone — deleted (F08-T11) since the list was opened, or the
/// id no longer resolves. Not a failure: the screen sends the user back
/// rather than reporting an error about a paper they no longer have.
final class DocumentDetailsNotFound extends DocumentDetailsState {
  const DocumentDetailsNotFound();
}

/// The document could not be read.
final class DocumentDetailsUnavailable extends DocumentDetailsState {
  const DocumentDetailsUnavailable(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is DocumentDetailsUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(DocumentDetailsUnavailable, failure);
}
