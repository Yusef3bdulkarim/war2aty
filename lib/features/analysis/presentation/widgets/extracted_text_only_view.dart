import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the text-only page.
const double _topBarTop = 56 - 52;
const double _topBarBottom = 12;
const double _topBarButton = 40;
const double _topBarGap = 8;
const double _topBarFontSize = 16;
const double _bodyPadding = 18;
const double _noteRadius = 12;
const double _notePaddingH = 13;
const double _notePaddingV = 11;
const double _noteGap = 8;
const double _noteIconSize = 16;
const double _noteFontSize = 12.5;
const double _noteHeight = 1.6;
const double _noteGapBelow = 14;
const double _cardPadding = 18;
const double _textFontSize = 14.5;
const double _textHeight = 2;
const double _actionsPaddingH = 16;
const double _actionsPaddingTop = 12;
const double _actionsPaddingBottom = 28;
const double _actionGap = 10;
const double _actionHeight = 52;
const double _actionRadius = 15;
const double _actionFontSize = 15;

/// How long the "copied" confirmation stays up.
const Duration _copiedFeedback = Duration(seconds: 2);

/// The fallback page: what was read off the paper, with no explanation.
///
/// Where the user lands when the analysis could not run or would not be
/// trustworthy — no internet, the day's analyses used up, the service down, a
/// paper this app cannot responsibly explain. The OCR already happened on the
/// phone, so this costs nothing and uses none of the daily allowance; showing
/// it beats sending the user away with nothing.
///
/// It says plainly that there is no explanation here, so the raw text is never
/// mistaken for one.
class ExtractedTextOnlyView extends StatelessWidget {
  const ExtractedTextOnlyView({
    required this.text,
    this.onBack,
    this.onListen,
    super.key,
  });

  /// The normalized OCR text.
  final String text;

  final VoidCallback? onBack;

  /// Reads it aloud. Absent until there is a reader for it (F10).
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Column(
      children: [
        _TopBar(onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(_bodyPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _NoExplanationNote(),
                const SizedBox(height: _noteGapBelow),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: AppShadows.low,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_cardPadding),
                    child: SelectableText(
                      text,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: _textFontSize,
                        height: _textHeight,
                        color: colors.textBody,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(top: BorderSide(color: colors.borderSoft)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _actionsPaddingH,
              _actionsPaddingTop,
              _actionsPaddingH,
              _actionsPaddingBottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Action(
                    label: strings.actionCopy,
                    background: colors.surfaceTeal,
                    foreground: colors.brandPrimary,
                    onPressed: () => _copy(context),
                  ),
                ),
                if (onListen case final onListen?) ...[
                  const SizedBox(width: _actionGap),
                  Expanded(
                    child: _Action(
                      label: strings.resultListenToText,
                      background: colors.brandPrimary,
                      foreground: colors.onBrand,
                      onPressed: onListen,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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

/// The page's bar: a way back, and the page's name.
class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            _topBarTop,
            AppSpacing.screenHorizontal,
            _topBarBottom,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: _topBarButton,
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  tooltip: strings.analysisResultBackLabel,
                  icon: Transform.flip(
                    flipX: mirror,
                    child: StrokeIcon(
                      StrokeGlyph.arrowBack,
                      color: colors.ink,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.extractedTextOnlyTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelCard.copyWith(
                      fontSize: _topBarFontSize,
                      fontWeight: AppTypography.extraBold,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              // Balances the back button so the title stays centred.
              const SizedBox.square(dimension: _topBarButton),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says there is no explanation here, so the raw text is not read as one.
class _NoExplanationNote extends StatelessWidget {
  const _NoExplanationNote();

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
                strings.extractedTextOnlyNote,
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

/// One of the bar's actions.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _actionHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_actionRadius),
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            fontSize: _actionFontSize,
            fontWeight: AppTypography.bold,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
