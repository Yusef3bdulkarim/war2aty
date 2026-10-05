import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/stroke_icon.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'top_bar_icon_button.dart';

// The owner's result-screen review, mockup A (F21 locked decisions #14, #19,
// #20). In the mockup the bar sits 56px from the physical top: a 52px status
// bar plus 4px. Here the status bar's height comes from [SafeArea], so only
// the 4px is a constant.
const double _barTop = 56 - 52;
const double _barBottom = 4;
const double _barSide = AppSpacing.screenHorizontal;
const double _barRadius = 28;
// Between the arrow and a [TealTopBar.title], and between the title and
// whatever balances the arrow on the other side (F26-T01).
const double _titleGap = 8;

/// The slim teal bar at the top of the result page and of the pages shown
/// when there is no result (F23 #2): the back arrow on the teal, its bottom
/// corners rounded, and [trailing] at the end.
///
/// No title is drawn unless [title] is given (F26 #2): the pages without a
/// teal hero of their own — reminder details, the reminder form, the privacy
/// policy — print their name there, white and centred. Without it, [heading],
/// when given, is announced as the page's heading to a screen reader; a page
/// that prints its own heading leaves both out, so the name is not read twice.
class TealTopBar extends StatelessWidget {
  const TealTopBar({
    required this.backTooltip,
    this.heading,
    this.title,
    this.onBack,
    this.trailing,
    super.key,
  }) : assert(
         heading == null || title == null,
         'A visible title is already the heading',
       );

  /// The page's name, for screen readers only.
  final String? heading;

  /// The page's name, drawn on the bar and announced as its heading.
  final String? title;

  final String backTooltip;

  /// Leaves the page. Absent in a widget test that pumps the page alone.
  final VoidCallback? onBack;

  /// Drawn at the bar's end, on the teal — so in white.
  final Widget? trailing;

  /// The bar's full height, status bar included — what a page scrolling
  /// under it holds back. Only for a bar without a [title], which can grow
  /// taller at a large text scale.
  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _barTop +
      TopBarIconButton.dimension +
      _barBottom;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;
    final heading = this.heading;
    final title = this.title;

    final backButton = TopBarIconButton(
      onPressed: onBack,
      tooltip: backTooltip,
      icon: Transform.flip(
        flipX: mirror,
        child: StrokeIcon(
          StrokeGlyph.arrowBack,
          color: colors.onBrand,
          strokeWidth: 2,
        ),
      ),
    );

    // Light status-bar icons: they sit on the teal.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.brandPrimary,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(_barRadius),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _barSide,
              _barTop,
              _barSide,
              _barBottom,
            ),
            child: title == null
                ? SizedBox(
                    height: TopBarIconButton.dimension,
                    child: Row(
                      children: [
                        backButton,
                        // The rest of the row carries the page's heading, so
                        // it has real bounds for a screen reader to land on.
                        Expanded(
                          child: heading == null
                              ? const SizedBox.expand()
                              : Semantics(
                                  header: true,
                                  label: heading,
                                  child: const SizedBox.expand(),
                                ),
                        ),
                        ?trailing,
                      ],
                    ),
                  )
                // A title may wrap at a large text scale, so the bar grows
                // with it rather than clipping it.
                : ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: TopBarIconButton.dimension,
                    ),
                    child: Row(
                      children: [
                        backButton,
                        const SizedBox(width: _titleGap),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelCard.copyWith(
                                fontWeight: AppTypography.extraBold,
                                color: colors.onBrand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: _titleGap),
                        // Balances the arrow so the title stays centred.
                        trailing ??
                            const SizedBox(width: TopBarIconButton.dimension),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
