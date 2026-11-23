import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import 'paper_card_shell.dart';

const double _addressFontSize = 17;
const double _addressLineHeight = 1.8;
const double _buttonGap = 12;
const double _buttonHeight = 50;
const double _buttonIconSize = 20;
const double _buttonIconGap = 8;

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    required this.address,
    required this.onEnlarge,
    this.isHighlighted = false,
    super.key,
  });

  final String address;
  final VoidCallback onEnlarge;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return PaperCardShell(
      icon: StrokeGlyph.locationPin,
      title: strings.paperPlaceCardTitle,
      titleColor: colors.textBodySoft,
      background: colors.card,
      borderColor: colors.borderSoft,
      iconBackground: colors.surfaceNeutral,
      iconColor: colors.iconInfo,
      isHighlighted: isHighlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            address,
            style: AppTypography.bodyLead.copyWith(
              fontSize: _addressFontSize,
              fontWeight: AppTypography.bold,
              height: _addressLineHeight,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: _buttonGap),
          _EnlargeButton(
            onPressed: onEnlarge,
            label: strings.paperPlaceCardEnlargeLabel,
          ),
        ],
      ),
    );
  }
}

class _EnlargeButton extends StatelessWidget {
  const _EnlargeButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: _buttonHeight,
        child: Material(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StrokeIcon(
                    StrokeGlyph.expand,
                    color: colors.ink,
                    size: _buttonIconSize,
                  ),
                  const SizedBox(width: _buttonIconGap),
                  Text(
                    label,
                    style: AppTypography.labelCard.copyWith(
                      fontSize: 15,
                      fontWeight: AppTypography.bold,
                      color: colors.ink,
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
