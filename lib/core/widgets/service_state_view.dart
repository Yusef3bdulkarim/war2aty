import 'package:flutter/material.dart';

import '../icons/stroke_icon.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'teal_top_bar.dart';

// The failure pages' redesign (F23): the result page's teal bar, the words,
// the page's own content, and the actions pinned at the bottom. The mockups
// are the F23 canvas's frames; the icon panel the Waraqti design had above
// the title is gone (F23 #4).
const double _bodyPaddingTop = 24;
const double _bodyPaddingH = 18;
const double _bodyPaddingBottom = 16;
const double _wordsPaddingH = 12;
const double _titleFontSize = 21;
const double _titleGapBelow = 12;
const double _messageFontSize = 15.5;
const double _messageHeight = 1.8;
const double _noteGap = 12;
const double _contentGap = 16;
const double _actionsPaddingH = 20;
const double _actionsPaddingTop = 14;
const double _actionsPaddingBottom = 30;
const double _primaryHeight = 54;
const double _secondaryHeight = 52;
const double _tertiaryHeight = 48;
const double _actionRadius = 15;
const double _actionGap = 9;
const double _actionFontSize = 16;
const double _pairFontSize = 15;
const double _tertiaryFontSize = 15;
const double _actionIconSize = 20;
const double _actionIconGap = 8;

/// From this text scale on, a side-by-side pair of actions stacks: two
/// Arabic labels no longer fit half the width each (F23 #13).
const double pairedActionsStackScale = 1.3;

/// One thing the user can do from a state page.
class ServiceStateAction {
  const ServiceStateAction({
    required this.label,
    required this.onPressed,
    this.glyph,
  });

  final String label;
  final VoidCallback onPressed;

  /// Drawn before the label, in the label's colour.
  final StrokeGlyph? glyph;
}

/// A full page that explains why there is no result, and what to do instead.
///
/// Every one of these states has a way forward — the extracted text, a retry,
/// another photo — because the user has already spent the effort of taking the
/// picture. A dead end here would throw that away.
///
/// The pages share this layout so they read as the same app talking: the
/// teal bar, a centred [title] and [message], an optional [note] under them,
/// then whatever [content] the page brings (cards of tips, a countdown, the
/// supported papers). The words and content scroll; the actions stay pinned.
class ServiceStateView extends StatelessWidget {
  const ServiceStateView({
    required this.title,
    required this.message,
    required this.primary,
    this.secondary,
    this.tertiary,
    this.note,
    this.content = const [],
    this.pairPrimaryActions = false,
    this.onBack,
    super.key,
  });

  final String title;
  final String message;

  /// A small line under the message, such as a reassurance.
  final Widget? note;

  /// The page's own blocks, below the words, in order.
  final List<Widget> content;

  final ServiceStateAction primary;
  final ServiceStateAction? secondary;

  /// The quiet last action, drawn as text.
  final ServiceStateAction? tertiary;

  /// Draws [primary] and [secondary] side by side, as two equal choices,
  /// until the text grows to [pairedActionsStackScale].
  final bool pairPrimaryActions;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final note = this.note;

    return Column(
      children: [
        // The page prints its own heading, so the bar announces none.
        TealTopBar(
          backTooltip: strings.analysisResultBackLabel,
          onBack: onBack,
        ),
        Expanded(
          // Scrollable rather than centred-and-clipped: under Large Text the
          // words and the cards together outgrow a small phone.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _bodyPaddingH,
              _bodyPaddingTop,
              _bodyPaddingH,
              _bodyPaddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _wordsPaddingH,
                  ),
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: _titleFontSize,
                            fontWeight: AppTypography.extraBold,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: _titleGapBelow),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: _messageFontSize,
                          fontWeight: AppTypography.medium,
                          height: _messageHeight,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (note != null) ...[
                        const SizedBox(height: _noteGap),
                        note,
                      ],
                    ],
                  ),
                ),
                for (final block in content) ...[
                  const SizedBox(height: _contentGap),
                  block,
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _actionsPaddingH,
            _actionsPaddingTop,
            _actionsPaddingH,
            _actionsPaddingBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._leadingActions(context, colors),
              if (tertiary case final tertiary?) ...[
                const SizedBox(height: _actionGap),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _tertiaryHeight),
                  child: TextButton(
                    onPressed: tertiary.onPressed,
                    style: TextButton.styleFrom(
                      // `textSecondary`, not `textMuted`: the muted grey is
                      // under 3:1 on the page (F23 #16).
                      foregroundColor: colors.textSecondary,
                      textStyle: AppTypography.labelCard.copyWith(
                        fontSize: _tertiaryFontSize,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    child: Text(tertiary.label, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The filled buttons: one under the other, or [primary] and [secondary]
  /// in one row when [pairPrimaryActions] asks for it and the text still fits.
  List<Widget> _leadingActions(BuildContext context, AppColors colors) {
    final primaryButton = _Action(
      action: primary,
      minHeight: _primaryHeight,
      background: colors.brandPrimary,
      foreground: colors.onBrand,
      fontSize: pairPrimaryActions ? _pairFontSize : _actionFontSize,
    );
    final secondary = this.secondary;
    if (secondary == null) return [primaryButton];

    final paired =
        pairPrimaryActions &&
        MediaQuery.textScalerOf(context).scale(1) < pairedActionsStackScale;
    final secondaryButton = _Action(
      action: secondary,
      // A pair is two equal choices, so both take the primary's height.
      minHeight: pairPrimaryActions ? _primaryHeight : _secondaryHeight,
      background: colors.surfaceTeal,
      foreground: colors.brandPrimary,
      fontSize: pairPrimaryActions ? _pairFontSize : _actionFontSize,
    );
    if (paired) {
      return [
        // Equal heights even when one label wraps: the row takes the taller
        // button's height and stretches the other to it.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: primaryButton),
              const SizedBox(width: _actionGap),
              Expanded(child: secondaryButton),
            ],
          ),
        ),
      ];
    }
    return [primaryButton, const SizedBox(height: _actionGap), secondaryButton];
  }
}

/// One of the filled buttons. It grows with Large Text rather than clipping
/// its label.
class _Action extends StatelessWidget {
  const _Action({
    required this.action,
    required this.minHeight,
    required this.background,
    required this.foreground,
    required this.fontSize,
  });

  final ServiceStateAction action;
  final double minHeight;
  final Color background;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final glyph = action.glyph;
    final label = Text(action.label, textAlign: TextAlign.center);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: FilledButton(
        onPressed: action.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_actionRadius),
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            fontSize: fontSize,
            fontWeight: AppTypography.bold,
          ),
        ),
        child: glyph == null
            ? label
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StrokeIcon(
                    glyph,
                    color: foreground,
                    size: _actionIconSize,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: _actionIconGap),
                  Flexible(child: label),
                ],
              ),
      ),
    );
  }
}
