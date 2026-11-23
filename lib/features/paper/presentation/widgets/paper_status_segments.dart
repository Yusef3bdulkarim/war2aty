import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const double _segmentHeight = 4;
const double _segmentGap = 4;
const double _segmentRadius = 2;

class PaperStatusSegments extends StatelessWidget {
  const PaperStatusSegments({
    required this.cardIds,
    this.activeId,
    this.fillFraction = 0,
    super.key,
  });

  final List<String> cardIds;
  final String? activeId;
  final double fillFraction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = activeId;
    final activeIndex = active == null ? -1 : cardIds.indexOf(active);
    final clampedFill = fillFraction.clamp(0.0, 1.0);

    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (index, id) in cardIds.indexed) ...[
            if (index > 0) const SizedBox(width: _segmentGap),
            Expanded(
              child: _Segment(
                id: id,
                fill: switch (index) {
                  _ when index < activeIndex => 1.0,
                  _ when index == activeIndex => clampedFill,
                  _ => 0.0,
                },
                trackColor: colors.borderSoft,
                fillColor: colors.brandPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.id,
    required this.fill,
    required this.trackColor,
    required this.fillColor,
  });

  final String id;
  final double fill;
  final Color trackColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('paper-status-segment-$id'),
      height: _segmentHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(_segmentRadius),
      ),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: fill,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(_segmentRadius),
          ),
        ),
      ),
    );
  }
}
