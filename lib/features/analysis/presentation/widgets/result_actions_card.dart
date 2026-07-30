import 'package:flutter/material.dart';

import '../../../../core/documents/required_action.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import 'caveat_badge.dart';

// From `Waraqti.dc.html` → the result page's «المطلوب منك» card.
const double _cardPadding = 18;
const double _cardGapBelow = 14;
const double _accentWidth = 5;
const double _titleIconSize = 20;
const double _titleGap = 8;
const double _titleGapBelow = 8;
const double _titleFontSize = 15;
const double _actionFontSize = 16;
const double _actionHeight = 1.75;
const double _badgeGapAbove = 8;
const double _actionGap = 12;

/// «المطلوب منك» — what this paper asks of the user.
///
/// The card is marked down its leading edge because this is the one block the
/// user has to act on; everything else on the page explains the paper.
///
/// An action the analysis worked out rather than read is labelled as such,
/// whatever its confidence (API_CONTRACT §30.5): the user must never be told
/// to pay or attend something on the app's own inference without knowing that
/// is what it is.
class ResultActionsCard extends StatelessWidget {
  const ResultActionsCard({required this.actions, super.key});

  /// In the order the analysis reported them — never empty, since
  /// `BuildAnalysisResult` drops the section otherwise.
  ///
  /// `ActionPriority` is deliberately not rendered: the design draws no
  /// second treatment for a high-priority action, and inventing one would put
  /// weight on the page the design never asked for.
  final List<RequiredAction> actions;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(bottom: _cardGapBelow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Stack(
            children: [
              Padding(
                // The leading inset clears the accent strip, the way the
                // design's border-box card puts its padding inside its border.
                padding: const EdgeInsetsDirectional.fromSTEB(
                  _accentWidth + _cardPadding,
                  _cardPadding,
                  _cardPadding,
                  _cardPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StrokeIcon(
                          StrokeGlyph.checkSquare,
                          color: colors.brandPrimary,
                          size: _titleIconSize,
                          strokeWidth: 2,
                        ),
                        const SizedBox(width: _titleGap),
                        Flexible(
                          child: Semantics(
                            header: true,
                            child: Text(
                              strings.resultActionRequiredTitle,
                              style: AppTypography.labelCard.copyWith(
                                fontSize: _titleFontSize,
                                fontWeight: AppTypography.extraBold,
                                color: colors.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _titleGapBelow),
                    for (final (index, action) in actions.indexed) ...[
                      if (index > 0) const SizedBox(height: _actionGap),
                      _Action(action: action),
                    ],
                  ],
                ),
              ),
              // A painted strip rather than a one-sided border: Flutter cannot
              // round the corners of a border that is not uniform. Positioned
              // so it runs the card's full height without measuring it.
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: _accentWidth,
                child: ColoredBox(color: colors.brandPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One instruction, with the basis badge when the paper did not say it.
class _Action extends StatelessWidget {
  const _Action({required this.action});

  final RequiredAction action;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          action.description,
          style: AppTypography.bodyLarge.copyWith(
            fontSize: _actionFontSize,
            fontWeight: AppTypography.semiBold,
            height: _actionHeight,
            color: colors.textBody,
          ),
        ),
        if (action.basis == ActionBasis.inferred) ...[
          const SizedBox(height: _badgeGapAbove),
          CaveatBadge(text: strings.resultActionInferred),
        ],
      ],
    );
  }
}
