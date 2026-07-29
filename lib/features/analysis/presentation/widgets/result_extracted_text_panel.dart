import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'expandable_panel.dart';

// From `Waraqti.dc.html` → the result page's extracted-text panel.
const double _gapAbove = 10;
const double _textFontSize = 13.5;
const double _textHeight = 1.9;
const double _textGapBelow = 12;
const double _noteRadius = 12;
const double _notePaddingH = 12;
const double _notePaddingV = 10;
const double _noteGap = 7;
const double _noteIconSize = 16;
const double _noteFontSize = 12.5;
const double _noteHeight = 1.6;
const double _noteGapBelow = 12;
const double _buttonGap = 10;
const double _buttonHeight = 44;
const double _buttonRadius = 12;
const double _buttonFontSize = 14;

/// How long the "copied" confirmation stays up.
const Duration _copiedFeedback = Duration(seconds: 2);

/// «عرض النص المستخرج» — what was actually read off the paper.
///
/// The last block on the page and the one that is never dropped while there is
/// any text at all (UX rule §5.12): whatever the analysis made of the paper,
/// the user can always see what it was working from and judge it themselves.
///
/// It is shown under a standing caution, because this is a machine reading and
/// not the paper — and it can be copied, so a number the app read wrongly can
/// still be pulled out and fixed by hand.
class ResultExtractedTextPanel extends StatelessWidget {
  const ResultExtractedTextPanel({
    required this.text,
    this.onListen,
    super.key,
  });

  /// The normalized OCR text. Never empty — `BuildAnalysisResult` drops the
  /// section otherwise.
  final String text;

  /// Reads the text aloud. Absent until there is a reader for it (F10); the
  /// button is left out entirely while it is.
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return ExpandablePanel(
      label: strings.resultShowExtractedText,
      gapAbove: _gapAbove,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selectable, not a plain [Text]: a user checking one line against
          // the paper in their hand wants to lift just that line out.
          SelectableText(
            text,
            style: AppTypography.caption.copyWith(
              fontSize: _textFontSize,
              fontWeight: AppTypography.regular,
              height: _textHeight,
              color: colors.textBody,
            ),
          ),
          const SizedBox(height: _textGapBelow),
          const _ReadingCaution(),
          const SizedBox(height: _noteGapBelow),
          Row(
            children: [
              Expanded(
                child: _PanelButton(
                  label: strings.actionCopy,
                  onPressed: () => _copy(context),
                ),
              ),
              if (onListen case final onListen?) ...[
                const SizedBox(width: _buttonGap),
                Expanded(
                  child: _PanelButton(
                    label: strings.resultListenToText,
                    onPressed: onListen,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.ocrTextCopied),
        duration: _copiedFeedback,
      ),
    );
  }
}

/// The amber line reminding the reader that this is a reading, not the paper.
class _ReadingCaution extends StatelessWidget {
  const _ReadingCaution();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.warningTint,
        borderRadius: BorderRadius.circular(_noteRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _notePaddingH,
          vertical: _notePaddingV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: StrokeIcon(
                StrokeGlyph.info,
                color: colors.warning,
                size: _noteIconSize,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: _noteGap),
            Expanded(
              child: Text(
                strings.resultExtractedTextWarning,
                style: AppTypography.caption.copyWith(
                  fontSize: _noteFontSize,
                  fontWeight: AppTypography.semiBold,
                  height: _noteHeight,
                  color: colors.warningInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the panel's two flat actions.
class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return SizedBox(
      height: _buttonHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.surfaceTeal,
          foregroundColor: colors.brandPrimary,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          textStyle: AppTypography.labelMedium.copyWith(
            fontSize: _buttonFontSize,
            fontWeight: AppTypography.bold,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
