import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// From `Waraqti.dc.html` → `camera`.
const double _frameRadius = 14;
const double _bracket = 34;
const double _bracketStroke = 3;

/// The dashed guide the user lines the paper up inside, with mint corner
/// brackets and a sweeping scan line.
///
/// Signals "hold it here" — the camera screen (F15) measures this box's real
/// on-screen position at capture time and crops to it (with a safety
/// margin), so what's kept is (approximately) what was framed. The scan line
/// animates continuously, so any screen showing it must be pumped without
/// `pumpAndSettle` in tests.
class ViewfinderFrame extends StatelessWidget {
  const ViewfinderFrame({super.key});

  /// The guide box's fixed size, from `Waraqti.dc.html` → `camera`. Public so
  /// the camera screen can compute the box's on-screen rect without
  /// duplicating these numbers.
  static const double width = 290;
  static const double height = 380;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        height: height,
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
    final mint = AppColors.of(context).mint;
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
    final mint = AppColors.of(context).mint;

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
