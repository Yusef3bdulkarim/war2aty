import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'paper_card_shell.dart';

const double _rowGap = 12;
const double _nameFontSize = 17;
const double _phoneFontSize = 22;
const double _buttonSize = 60;
const double _buttonIconSize = 28;

class ContactCard extends StatelessWidget {
  const ContactCard({
    required this.name,
    required this.groupedPhone,
    required this.onCall,
    this.isHighlighted = false,
    super.key,
  });

  final String name;
  final String groupedPhone;
  final VoidCallback onCall;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return PaperCardShell(
      icon: StrokeGlyph.phone,
      title: strings.paperContactCardTitle,
      titleColor: colors.successInk,
      background: colors.card,
      borderColor: colors.borderSoft,
      iconBackground: colors.successTint,
      iconColor: colors.successInk,
      isHighlighted: isHighlighted,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.labelCard.copyWith(
                    fontSize: _nameFontSize,
                    fontWeight: AppTypography.extraBold,
                    color: colors.ink,
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    groupedPhone,
                    textAlign: TextAlign.right,
                    style: AppTypography.labelCard.copyWith(
                      fontSize: _phoneFontSize,
                      fontWeight: AppTypography.extraBold,
                      letterSpacing: 1,
                      color: colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _rowGap),
          _CallButton(
            onPressed: onCall,
            label: strings.paperContactCardCallLabel(name),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.onPressed, required this.label});

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
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.success,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: StrokeIcon(
                StrokeGlyph.phone,
                color: colors.onBrand,
                size: _buttonIconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
