import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the partial-result banner above the result page.
const double _radius = 16;
const double _paddingH = 15;
const double _paddingV = 14;
const double _gap = 11;
const double _gapBelow = 16;
const double _iconSize = 22;
const double _fontSize = 13.5;
const double _height = 1.6;

/// «قدرنا نفهم جزء من الورقة» — said above a result that is only half read.
///
/// A partial result is still shown rather than thrown away: what was
/// understood is usually the part the user came for. But it is topped with
/// this, because a page that looks like every other result would be read as a
/// complete one — and the uncertain values further down each carry their own
/// caution (UX rules §5.9, §5.11).
class PartialResultBanner extends StatelessWidget {
  const PartialResultBanner({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(bottom: _gapBelow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.warningTint,
          border: Border.all(color: colors.warningBorder),
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
                padding: const EdgeInsets.only(top: 1),
                child: StrokeIcon(
                  StrokeGlyph.warningTriangle,
                  color: colors.warning,
                  size: _iconSize,
                  strokeWidth: 1.9,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Text(
                  strings.resultPartialBanner,
                  style: AppTypography.caption.copyWith(
                    fontSize: _fontSize,
                    fontWeight: AppTypography.semiBold,
                    height: _height,
                    color: colors.warningInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
