import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → `isDocuments`, the `noDocs` block.
const double _gapAbove = 56;
const double _artWidth = 120;
const double _artHeight = 104;
const double _paperWidth = 74;
const double _paperHeight = 92;
const double _paperTilt = -7 * math.pi / 180;
const double _cameraTile = 56;
const double _titleGap = 22;
const double _subtitleGap = 22;

/// Illustration-only accents for the mock "lines of text" on the second
/// paper — decorative, not semantic UI colors, so they live here rather than
/// in [AppColors] (the same reasoning as [AppShadows]'s literal rgba values).
const Color _linedPaperFill = Color(0xFFEDEAE2);
const Color _linedPaperBorder = Color(0xFFDED9CE);
const Color _lineDark = Color(0xFFD3CDBF);
const Color _lineLight = Color(0xFFDED9CE);

/// Shown on the «مستنداتي» screen when there is nothing to list — either
/// nothing has ever been saved (F08-T05), or a search matched nothing
/// (F08-T06). No dedicated design exists for the search case, so it reuses
/// this illustration with different copy and without the scan CTA, which
/// would not help a search that is off.
class DocumentsEmptyState extends StatelessWidget {
  /// Nothing has been saved yet — the design's `noDocs` state.
  const DocumentsEmptyState({required this.onScan, super.key})
    : _isSearch = false;

  /// A search matched nothing, while the library itself is not empty.
  const DocumentsEmptyState.noResults({super.key})
    : onScan = null,
      _isSearch = true;

  /// Where the primary action leads — the capture flow already exists, so
  /// this is always wired, unlike a document row's still-unbuilt destination.
  /// `null` for [DocumentsEmptyState.noResults], which shows no action.
  final VoidCallback? onScan;

  final bool _isSearch;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        _gapAbove,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          const _EmptyArt(),
          const SizedBox(height: _titleGap),
          Text(
            _isSearch ? s.documentsSearchNoResultsTitle : s.documentsEmptyTitle,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: AppTypography.extraBold,
              color: colors.textBody,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearch
                ? s.documentsSearchNoResultsSubtitle
                : s.documentsEmptySubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textCaption,
              fontWeight: AppTypography.medium,
            ),
          ),
          if (!_isSearch) ...[
            const SizedBox(height: _subtitleGap),
            FilledButton(
              onPressed: onScan,
              style: FilledButton.styleFrom(
                backgroundColor: colors.brandPrimary,
                foregroundColor: colors.onBrand,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                textStyle: AppTypography.labelLarge,
              ),
              child: Text(s.documentsEmptyCta),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two overlapping sheets — one blank, one with mock text lines — under a
/// camera tile. A more detailed cousin of Home's empty-state art: this one
/// speaks specifically to "nothing saved", so it draws the paper *with*
/// content rather than a blank one.
class _EmptyArt extends StatelessWidget {
  const _EmptyArt();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ExcludeSemantics(
      child: SizedBox(
        width: _artWidth,
        height: _artHeight,
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 2,
              child: Transform.rotate(
                angle: _paperTilt,
                child: Container(
                  width: _paperWidth,
                  height: _paperHeight,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.paper,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              top: 14,
              child: Container(
                width: _paperWidth,
                height: _paperHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _linedPaperFill,
                  border: Border.all(color: _linedPaperBorder, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TextLine(width: 0.7, height: 6, color: _lineDark),
                    SizedBox(height: 7),
                    _TextLine(color: _lineLight),
                    SizedBox(height: 7),
                    _TextLine(width: 0.85, color: _lineLight),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: _cameraTile,
                height: _cameraTile,
                decoration: BoxDecoration(
                  color: colors.brandPrimary,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D0E7C86),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: StrokeIcon(
                    StrokeGlyph.camera,
                    color: colors.onBrand,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One hairline bar standing in for a line of text on the mock paper.
class _TextLine extends StatelessWidget {
  const _TextLine({this.width = 1, this.height = 5, required this.color});

  /// Fraction of the paper's content width this line fills.
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
