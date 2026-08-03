import 'package:flutter/foundation.dart';

import '../../../../core/documents/recent_document.dart';
import '../../../../core/error/app_failure.dart';

/// State of the «مستنداتي» screen (F08-T05).
///
/// Its own sealed union rather than reusing Home's `DocumentsSection`: that
/// type belongs to the `home` feature, and cross-feature imports are not
/// allowed (CLAUDE.md §B1) even for two states that happen to look alike
/// today — the list screen's is bounded by nothing while Home's is bounded to
/// a handful, and F08-T07 will add a category filter that Home's never needs.
sealed class DocumentsListState {
  const DocumentsListState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No list has arrived from the database yet.
final class DocumentsListLoading extends DocumentsListState {
  const DocumentsListLoading();
}

/// Every saved document, newest first, or an empty list when nothing is saved
/// yet — both are answers, not failures.
final class DocumentsListAvailable extends DocumentsListState {
  const DocumentsListAvailable(this.documents);

  final List<RecentDocument> documents;

  bool get isEmpty => documents.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is DocumentsListAvailable &&
      listEquals(other.documents, documents);

  @override
  int get hashCode => Object.hashAll(documents);
}

/// The list could not be read. Unlike Home's recent strip, this screen has
/// nothing else to show in its place, so the screen renders this rather than
/// hiding and looking like an empty library.
final class DocumentsListUnavailable extends DocumentsListState {
  const DocumentsListUnavailable(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is DocumentsListUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(DocumentsListUnavailable, failure);
}
