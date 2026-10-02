import 'package:flutter/material.dart';

import '../../../../../core/icons/stroke_icon.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

const double _radius = 18;
const double _padding = 16;
const double _rowGap = 12;
const double _iconBox = 36;
const double _iconBoxRadius = 10;
const double _iconSize = 19;
const double _iconGap = 12;
const double _titleFontSize = 15.5;
const double _tipFontSize = 14;
const double _tipHeight = 1.6;

/// How a tip's icon tile is coloured.
enum FailureTipTone {
  /// Teal: something to do or check.
  teal,

  /// Amber: a piece of advice, such as the daily-limit page's lightbulb.
  amber,
}

/// One line of advice on a failure page: an icon and its words.
class FailureTip {
  const FailureTip({
    required this.glyph,
    required this.text,
    this.tone = FailureTipTone.teal,
  });

  final StrokeGlyph glyph;
  final String text;
  final FailureTipTone tone;
}

/// A white card of advice under a failure page's words — «جرّب الحاجات دي»,
/// «تقدر تعمل إيه دلوقتي؟», «لو المشكلة اتكررت» (F23 #6–#8).
class FailureTipsCard extends StatelessWidget {
  const FailureTipsCard({required this.title, required this.tips, super.key});

  final String title;
  final List<FailureTip> tips;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            for (final tip in tips) ...[
              const SizedBox(height: _rowGap),
              _TipRow(tip: tip),
            ],
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});

  final FailureTip tip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (tint, ink) = switch (tip.tone) {
      FailureTipTone.teal => (colors.surfaceTealAlt, colors.brandPrimary),
      FailureTipTone.amber => (colors.warningTint, colors.warningInk),
    };

    return Row(
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
              tip.glyph,
              color: ink,
              size: _iconSize,
              strokeWidth: 2,
            ),
          ),
        ),
        const SizedBox(width: _iconGap),
        Expanded(
          child: Text(
            tip.text,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: _tipFontSize,
              fontWeight: AppTypography.semiBold,
              height: _tipHeight,
              color: colors.textBody,
            ),
          ),
        ),
      ],
    );
  }
}
