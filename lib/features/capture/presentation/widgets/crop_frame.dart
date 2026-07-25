import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// From `Waraqti.dc.html` → `preview`.
const double _bracket = 26;
const double _bracketStroke = 3;
const double _bracketInset = 9;
const double _imageRadius = 6;

/// Wraps [child] (the paper image) in the design's teal corner brackets.
///
/// A fixed guide, not a draggable crop: the brackets sit just outside the four
/// corners to signal "this is the paper we'll read", framing the whole image
/// rather than selecting a region of it.
class CropFrame extends StatelessWidget {
  const CropFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_imageRadius),
          child: child,
        ),
        const Positioned(
          top: -_bracketInset,
          left: -_bracketInset,
          child: _Corner(Alignment.topLeft),
        ),
        const Positioned(
          top: -_bracketInset,
          right: -_bracketInset,
          child: _Corner(Alignment.topRight),
        ),
        const Positioned(
          bottom: -_bracketInset,
          left: -_bracketInset,
          child: _Corner(Alignment.bottomLeft),
        ),
        const Positioned(
          bottom: -_bracketInset,
          right: -_bracketInset,
          child: _Corner(Alignment.bottomRight),
        ),
      ],
    );
  }
}

/// One mint L-bracket, on the two edges meeting at [corner].
class _Corner extends StatelessWidget {
  const _Corner(this.corner);

  final Alignment corner;

  @override
  Widget build(BuildContext context) {
    final mint = AppColors.light.mint;
    final side = BorderSide(color: mint, width: _bracketStroke);
    final isTop = corner.y < 0;
    final isLeft = corner.x < 0;

    return SizedBox(
      width: _bracket,
      height: _bracket,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? side : BorderSide.none,
            bottom: isTop ? BorderSide.none : side,
            left: isLeft ? side : BorderSide.none,
            right: isLeft ? BorderSide.none : side,
          ),
        ),
      ),
    );
  }
}
