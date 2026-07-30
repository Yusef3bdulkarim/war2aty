import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the service-state pages (no internet, daily limit,
// service down, unsupported paper). One layout, four sets of words.
const double _topPaddingTop = 56 - 52;
const double _topPaddingH = 16;
const double _topPaddingBottom = 12;
const double _backButton = 40;
const double _backIconSize = 22;
const double _bodyPaddingH = 30;
const double _bodyPaddingV = 20;
const double _iconBox = 96;
const double _iconBoxRadius = 28;
const double _iconSize = 46;
const double _iconGapBelow = 24;
const double _titleFontSize = 21;
const double _titleGapBelow = 12;
const double _messageFontSize = 15.5;
const double _messageHeight = 1.8;
const double _actionsPaddingH = 20;
const double _actionsPaddingTop = 16;
const double _actionsPaddingBottom = 30;
const double _primaryHeight = 54;
const double _secondaryHeight = 52;
const double _tertiaryHeight = 48;
const double _actionRadius = 15;
const double _actionGap = 9;
const double _actionFontSize = 16;
const double _tertiaryFontSize = 15;

/// One thing the user can do from a state page.
class ServiceStateAction {
  const ServiceStateAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// A full page that explains why there is no result, and what to do instead.
///
/// Every one of these states has a way forward — the extracted text, a retry,
/// another photo — because the user has already spent the effort of taking the
/// picture. A dead end here would throw that away.
///
/// The four states share this layout so they read as the same app talking,
/// and each supplies its own words and its own tint.
class ServiceStateView extends StatelessWidget {
  const ServiceStateView({
    required this.glyph,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primary,
    this.secondary,
    this.tertiary,
    this.onBack,
    super.key,
  });

  final StrokeGlyph glyph;

  /// The icon panel's fill, and the colour of the glyph on it.
  final Color tint;
  final Color iconColor;

  final String title;
  final String message;

  final ServiceStateAction primary;
  final ServiceStateAction? secondary;
  final ServiceStateAction? tertiary;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _topPaddingH,
              _topPaddingTop,
              _topPaddingH,
              _topPaddingBottom,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.card,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.low,
                ),
                child: SizedBox.square(
                  dimension: _backButton,
                  child: IconButton(
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    tooltip: strings.analysisResultBackLabel,
                    icon: Transform.flip(
                      flipX: mirror,
                      child: StrokeIcon(
                        StrokeGlyph.arrowBack,
                        color: colors.ink,
                        size: _backIconSize,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          // Scrollable rather than centred-and-clipped: under Large Text the
          // icon, heading and message together outgrow a small phone.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: _bodyPaddingH,
              vertical: _bodyPaddingV,
            ),
            child: Column(
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(_iconBoxRadius),
                  ),
                  child: Center(
                    child: StrokeIcon(
                      glyph,
                      color: iconColor,
                      size: _iconSize,
                      strokeWidth: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: _iconGapBelow),
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
              _Action(
                action: primary,
                height: _primaryHeight,
                background: colors.brandPrimary,
                foreground: colors.onBrand,
              ),
              if (secondary case final secondary?) ...[
                const SizedBox(height: _actionGap),
                _Action(
                  action: secondary,
                  height: _secondaryHeight,
                  background: colors.surfaceTeal,
                  foreground: colors.brandPrimary,
                ),
              ],
              if (tertiary case final tertiary?) ...[
                const SizedBox(height: _actionGap),
                SizedBox(
                  height: _tertiaryHeight,
                  child: TextButton(
                    onPressed: tertiary.onPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textMuted,
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
}

/// One of the two filled buttons.
class _Action extends StatelessWidget {
  const _Action({
    required this.action,
    required this.height,
    required this.background,
    required this.foreground,
  });

  final ServiceStateAction action;
  final double height;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: action.onPressed,
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
        child: Text(action.label, textAlign: TextAlign.center),
      ),
    );
  }
}
