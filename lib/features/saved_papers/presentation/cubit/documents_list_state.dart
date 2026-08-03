import 'package:flutter/foundation.dart';

import '../../../../core/documents/document_category.dart';
import '../../../../core/documents/recent_document.dart';
import '../../../../core/error/app_failure.dart';

/// State of the «مستنداتي» screen (F08-T05).
///
/// Its own sealed union rather than reusing Home's `DocumentsSection`: that
/// type belongs to the `home` feature, and cross-feature imports are not
/// allowed (CLAUDE.md §B1) even for two states that happen to look alike
/// today — the list screen's is bounded by nothing while Home's is bounded to
/// a handful, and F08-T06/F08-T07 grow this one with a search term and a
/// category filter that Home's never needs.
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

/// Every saved document matching [query] and [category], newest first, or an
/// empty list when nothing is saved yet or nothing matched — both are
/// answers, not failures.
final class DocumentsListAvailable extends DocumentsListState {
  const DocumentsListAvailable(
    this.documents, {
    this.query = '',
    this.category,
  });

  final List<RecentDocument> documents;

  /// The title filter currently applied (F08-T06). Blank means unfiltered.
  final String query;

  /// The category chip currently active (F08-T07). `null` means «الكل» —
  /// every category.
  final DocumentCategory? category;

  bool get isEmpty => documents.isEmpty;

  /// Whether [isEmpty] means "nothing matched the active filter" rather than
  /// "nothing has ever been saved" — the two need different copy on screen.
  bool get isFiltered => query.trim().isNotEmpty || category != null;

  @override
  bool operator ==(Object other) =>
      other is DocumentsListAvailable &&
      other.query == query &&
      other.category == category &&
      listEquals(other.documents, documents);

  @override
  int get hashCode => Object.hash(query, category, Object.hashAll(documents));
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
