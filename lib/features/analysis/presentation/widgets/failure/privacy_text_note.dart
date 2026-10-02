import 'package:flutter/material.dart';

import '../../../../../core/icons/stroke_icon.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

const double _radius = 18;
const double _paddingH = 16;
const double _paddingV = 14;
const double _iconSize = 22;
const double _iconTop = 2;
const double _gap = 12;
const double _fontSize = 14;
const double _height = 1.7;

/// What happens to the text when analysis is on, on the consent-off page
/// (F23 #9) — the approved wording, word for word: `privacyPointTextOnly`,
/// the same string the app's privacy content uses, never a copy of it.
class PrivacyTextNote extends StatelessWidget {
  const PrivacyTextNote({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceTealAlt,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingH,
          vertical: _paddingV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _iconTop),
              child: StrokeIcon(
                StrokeGlyph.shieldCheck,
                color: colors.brandDeep,
                size: _iconSize,
                strokeWidth: 1.9,
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: Text(
                context.strings.privacyPointTextOnly,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: _fontSize,
                  fontWeight: AppTypography.semiBold,
                  height: _height,
                  color: colors.brandDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
