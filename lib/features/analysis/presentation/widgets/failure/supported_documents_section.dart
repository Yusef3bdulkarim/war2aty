import 'package:flutter/material.dart';

import '../../../../../core/documents/document_category.dart';
import '../../../../../core/documents/document_category_style.dart';
import '../../../../../core/icons/stroke_icon.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

const double _headingGap = 12;
const double _headingInset = 4;
const double _headingFontSize = 15.5;
const double _tileGap = 10;
const double _tileRadius = 16;
const double _tilePadding = 14;
const double _iconBox = 40;
const double _iconBoxRadius = 12;
const double _iconSize = 20;
const double _innerGap = 8;
const double _labelFontSize = 14.5;
const double _examplesFontSize = 12.5;
const double _examplesHeight = 1.6;

/// «الأوراق اللي بنشرحها» on the unsupported page (F23 #5, Option B): the
/// four categories in a 2 × 2 grid, then «أوراق تانية» across the width,
/// each with examples. Icons and tints are the categories' own
/// ([DocumentCategoryStyle]), so a kind looks the same here as everywhere.
///
/// «أوراق تانية» is listed on purpose: medical, legal and financial papers
/// are explained, they only file under [DocumentCategory.other].
class SupportedDocumentsSection extends StatelessWidget {
  const SupportedDocumentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    Widget tile(DocumentCategory category) => _Tile(
      category: category,
      label: _label(strings, category),
      examples: _examples(strings, category),
    );
    Widget pair(DocumentCategory start, DocumentCategory end) =>
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tile(start)),
              const SizedBox(width: _tileGap),
              Expanded(child: tile(end)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _headingInset),
          child: Semantics(
            header: true,
            child: Text(
              strings.analysisSupportedDocumentsTitle,
              style: AppTypography.titleMedium.copyWith(
                fontSize: _headingFontSize,
                fontWeight: AppTypography.extraBold,
                color: colors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: _headingGap),
        pair(DocumentCategory.invoice, DocumentCategory.appointment),
        const SizedBox(height: _tileGap),
        pair(DocumentCategory.government, DocumentCategory.education),
        const SizedBox(height: _tileGap),
        _Tile(
          category: DocumentCategory.other,
          label: strings.analysisSupportedOther,
          examples: strings.analysisSupportedOtherExamples,
          wide: true,
        ),
      ],
    );
  }

  static String _label(AppStrings s, DocumentCategory category) =>
      switch (category) {
        DocumentCategory.invoice => s.analysisSupportedInvoices,
        DocumentCategory.appointment => s.analysisSupportedAppointments,
        DocumentCategory.government => s.analysisSupportedGovernment,
        DocumentCategory.education => s.analysisSupportedEducation,
        DocumentCategory.other => s.analysisSupportedOther,
      };

  static String _examples(AppStrings s, DocumentCategory category) =>
      switch (category) {
        DocumentCategory.invoice => s.analysisSupportedInvoicesExamples,
        DocumentCategory.appointment => s.analysisSupportedAppointmentsExamples,
        DocumentCategory.government => s.analysisSupportedGovernmentExamples,
        DocumentCategory.education => s.analysisSupportedEducationExamples,
        DocumentCategory.other => s.analysisSupportedOtherExamples,
      };
}

/// One kind of paper: its icon tile, its name and its examples. A [wide] tile
/// puts the icon beside the words instead of above them.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.category,
    required this.label,
    required this.examples,
    this.wide = false,
  });

  final DocumentCategory category;
  final String label;
  final String examples;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = DocumentCategoryStyle.of(context, category);

    final icon = Container(
      width: _iconBox,
      height: _iconBox,
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(_iconBoxRadius),
      ),
      child: Center(
        child: StrokeIcon(
          style.glyph,
          color: style.foreground,
          size: _iconSize,
        ),
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelCard.copyWith(
            fontSize: _labelFontSize,
            fontWeight: AppTypography.bold,
            color: colors.ink,
          ),
        ),
        Text(
          examples,
          style: AppTypography.caption.copyWith(
            fontSize: _examplesFontSize,
            fontWeight: AppTypography.medium,
            height: _examplesHeight,
            color: colors.textSecondary,
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_tileRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_tilePadding),
        // One stop for a screen reader: the kind and its examples together.
        child: MergeSemantics(
          child: wide
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: _tilePadding - 2),
                    Expanded(child: words),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(height: _innerGap),
                    words,
                  ],
                ),
        ),
      ),
    );
  }
}
