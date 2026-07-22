import 'package:flutter/material.dart';

import '../../../../core/documents/document_category.dart';
import '../../../../core/documents/document_category_style.dart';
import '../../../../core/documents/recent_document.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../cubit/home_state.dart';

// From `Waraqti.dc.html` → `home`.
const double _sectionGapAbove = 24;
const double _headerGap = 11;
const double _cardPadding = 16;
const double _cardGap = 13;
const double _iconBox = 48;
const double _rowGap = 10;

/// "Recent documents", with a card per saved paper.
///
/// Hidden entirely until at least one document exists — Home's own empty state
/// (F02-T09) speaks for the whole screen, so an empty section here would just
/// repeat it.
class RecentDocumentsStrip extends StatelessWidget {
  const RecentDocumentsStrip({
    required this.section,
    this.onSeeAll,
    this.onOpenDocument,
    super.key,
  });

  final DocumentsSection section;

  /// Opens the full documents list (F08); null until that screen exists.
  final VoidCallback? onSeeAll;

  /// Opens one document (F08).
  final ValueChanged<RecentDocument>? onOpenDocument;

  /// The rows to draw, or `null` when the section stays hidden.
  static List<RecentDocument>? _documentsToShow(DocumentsSection section) =>
      switch (section) {
        DocumentsLoading() || DocumentsUnavailable() => null,
        DocumentsAvailable(:final documents) =>
          documents.isEmpty ? null : documents,
      };

  /// Whether this section renders anything at all.
  static bool isVisible(DocumentsSection section) =>
      _documentsToShow(section) != null;

  @override
  Widget build(BuildContext context) {
    if (section is DocumentsLoading) return const _DocumentsSkeleton();

    final documents = _documentsToShow(section);
    if (documents == null) return const SizedBox.shrink();

    final s = context.strings;
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.only(top: _sectionGapAbove),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    s.homeRecentDocumentsTitle,
                    style: AppTypography.titleMedium.copyWith(
                      color: colors.ink,
                      fontSize: 16,
                      fontWeight: AppTypography.extraBold,
                    ),
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.brandPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    s.homeSeeAll,
                    style: AppTypography.caption.copyWith(
                      fontSize: 13.5,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: _headerGap),
          for (final (index, document) in documents.indexed) ...[
            if (index > 0) const SizedBox(height: _rowGap),
            _DocumentCard(
              document: document,
              onTap: onOpenDocument == null
                  ? null
                  : () => onOpenDocument!(document),
            ),
          ],
        ],
      ),
    );
  }
}

/// One saved paper: tinted category icon, title, category chip, storage badge.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onTap});

  final RecentDocument document;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;
    final style = DocumentCategoryStyle.of(document.category);
    final radius = BorderRadius.circular(AppRadii.xl);
    final categoryName = _categoryName(s, document.category);
    final storage = _storageLabel(s, document.storageMode);

    return Semantics(
      button: onTap != null,
      // Read as one sentence rather than three disconnected fragments.
      label: '${document.title}. $categoryName. $storage',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.card,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: radius,
              boxShadow: AppShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _iconBox,
                    height: _iconBox,
                    decoration: BoxDecoration(
                      color: style.tint,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Center(
                      child: StrokeIcon(style.glyph, color: style.foreground),
                    ),
                  ),
                  const SizedBox(width: _cardGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelCard.copyWith(
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CategoryChip(label: categoryName, style: style),
                            Text(
                              storage,
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                color: colors.textMuted,
                                fontWeight: AppTypography.semiBold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.style});

  final String label;
  final DocumentCategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        child: Text(
          label,
          style: AppTypography.micro.copyWith(
            fontSize: 11.5,
            color: style.foreground,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
    );
  }
}

String _categoryName(AppStrings s, DocumentCategory category) =>
    switch (category) {
      DocumentCategory.appointment => s.documentCategoryAppointment,
      DocumentCategory.invoice => s.documentCategoryInvoice,
      DocumentCategory.government => s.documentCategoryGovernment,
      DocumentCategory.education => s.documentCategoryEducation,
      DocumentCategory.other => s.documentCategoryOther,
    };

String _storageLabel(AppStrings s, DocumentStorageMode mode) => switch (mode) {
  DocumentStorageMode.resultOnly => s.documentStoredResultOnly,
  DocumentStorageMode.withImage => s.documentStoredWithImage,
};

/// The strip's silhouette while the database is being read.
class _DocumentsSkeleton extends StatelessWidget {
  const _DocumentsSkeleton();

  /// Two rows: enough to read as a list without pretending to know how many
  /// documents will actually arrive.
  static const int _rows = 2;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.only(top: _sectionGapAbove),
      child: Shimmer(
        label: context.strings.stateLoading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 96, height: 16),
            const SizedBox(height: _headerGap),
            for (var row = 0; row < _rows; row++) ...[
              if (row > 0) const SizedBox(height: _rowGap),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(_cardPadding),
                  child: Row(
                    children: [
                      SkeletonBox(
                        width: _iconBox,
                        height: _iconBox,
                        radius: AppRadii.md,
                      ),
                      SizedBox(width: _cardGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(height: 15),
                            SizedBox(height: 9),
                            SkeletonBox(width: 120, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
