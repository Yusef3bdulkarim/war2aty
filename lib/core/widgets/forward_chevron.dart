import 'package:flutter/widgets.dart';

import '../icons/stroke_icon.dart';

/// [StrokeGlyph.chevronForward], pointing along the reading direction.
///
/// The glyph is drawn for RTL — pointing left — and [StrokeIcon] deliberately
/// mirrors nothing, since most glyphs must not flip. Every "this row opens
/// something" chevron therefore has to be mirrored by hand, and four of them
/// were not: the settings rows and the saved-papers card pointed *backwards*
/// in English (F27-T15). This is that one line, in one place, so the next
/// chevron cannot get it wrong.
class ForwardChevron extends StatelessWidget {
  const ForwardChevron({
    required this.color,
    this.size = 16,
    this.strokeWidth = 1.8,
    super.key,
  });

  final Color color;
  final double size;

  /// Matches [StrokeIcon]'s own default.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final icon = StrokeIcon(
      StrokeGlyph.chevronForward,
      color: color,
      size: size,
      strokeWidth: strokeWidth,
    );

    return Transform.flip(
      flipX: Directionality.of(context) == TextDirection.ltr,
      child: icon,
    );
  }
}
