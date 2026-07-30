import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// From `Waraqti.dc.html` → `camera`.
const double _frameWidth = 290;
const double _frameHeight = 380;
const double _frameRadius = 14;
const double _bracket = 34;
const double _bracketStroke = 3;

/// The dashed guide the user lines the paper up inside, with mint corner
/// brackets and a sweeping scan line.
///
/// Purely decorative: it frames the shot and signals "hold it here", but the
/// camera captures the full frame regardless of where this sits. The scan line
/// animates continuously, so any screen showing it must be pumped without
/// `pumpAndSettle` in tests.
class ViewfinderFrame extends StatelessWidget {
  const ViewfinderFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: _frameWidth,
        height: _frameHeight,
        child: Stack(
          children: [
            // The faint field the design fills the frame with. A dashed border
            // needs a custom painter; the mint brackets carry the shape, so a
            // hairline is enough here.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(_frameRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const _Corner(Alignment.topLeft),
            const _Corner(Alignment.topRight),
            const _Corner(Alignment.bottomLeft),
            const _Corner(Alignment.bottomRight),
            const Positioned.fill(child: _ScanLine()),
          ],
        ),
      ),
    );
  }
}

/// One mint L-bracket, drawn on the two edges that meet at [corner].
class _Corner extends StatelessWidget {
  const _Corner(this.corner);

  final Alignment corner;

  @override
  Widget build(BuildContext context) {
    final mint = AppColors.light.mint;
    final side = BorderSide(color: mint, width: _bracketStroke);
    final isTop = corner.y < 0;
    final isLeft = corner.x < 0;

    return Align(
      alignment: corner,
      child: SizedBox(
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
      ),
    );
  }
}

/// The mint line that sweeps up and down inside the frame.
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mint = AppColors.light.mint;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // -0.9..0.9 keeps the line just inside the frame's rounded corners.
        final t = (_controller.value * 2 - 1) * 0.9;
        return Align(
          alignment: Alignment(0, t),
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mint.withValues(alpha: 0),
                  mint,
                  mint.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
