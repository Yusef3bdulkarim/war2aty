import 'package:flutter/material.dart';

import '../../domain/entities/focus_point.dart';

/// The live feed, focusable by tapping it (F24).
///
/// A tap reports where it landed as fractions of the feed ([FocusPoint]), and
/// white corner brackets show the spot for a moment. With [enabled] off — a
/// lens that cannot focus on a point — the feed ignores taps entirely, so the
/// brackets never promise a focus that will not happen.
class FocusablePreview extends StatefulWidget {
  const FocusablePreview({
    required this.preview,
    required this.enabled,
    required this.onFocus,
    super.key,
  });

  final Widget preview;
  final bool enabled;
  final ValueChanged<FocusPoint> onFocus;

  @override
  State<FocusablePreview> createState() => _FocusablePreviewState();
}

class _FocusablePreviewState extends State<FocusablePreview>
    with SingleTickerProviderStateMixin {
  static const double _box = 76;

  // Created eagerly in initState: a lazy controller would first be built by
  // dispose(), on an element that is already deactivated.
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  Offset? _spot;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // In fast, hold, fade: the design's 0–14% / 14–70% / 70–100%.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 14),
      TweenSequenceItem(tween: ConstantTween(1), weight: 56),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
    ]).animate(_controller);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.35,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 86),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final spot = details.localPosition;
    setState(() => _spot = spot);
    _controller.forward(from: 0);
    widget.onFocus(FocusPoint(spot.dx / size.width, spot.dy / size.height));
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;

    // The tree stays the same shape whether or not taps are on, so arming and
    // disarming (mid-capture) never rebuilds the live feed beneath.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: widget.enabled ? _onTapUp : null,
      child: Stack(
        children: [
          widget.preview,
          if (spot != null)
            Positioned(
              left: spot.dx - _box / 2,
              top: spot.dy - _box / 2,
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _opacity,
                  child: ScaleTransition(
                    scale: _scale,
                    child: const CustomPaint(
                      size: Size.square(_box),
                      painter: _BracketsPainter(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Four white corner brackets with a dark halo, so they read on a white page
/// as well as on a dark desk.
class _BracketsPainter extends CustomPainter {
  const _BracketsPainter();

  static const double _arm = 17;
  static const double _radius = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    // Each corner: along one edge, round the corner, along the other.
    path
      ..moveTo(0, _arm)
      ..lineTo(0, _radius)
      ..quadraticBezierTo(0, 0, _radius, 0)
      ..lineTo(_arm, 0)
      ..moveTo(w - _arm, 0)
      ..lineTo(w - _radius, 0)
      ..quadraticBezierTo(w, 0, w, _radius)
      ..lineTo(w, _arm)
      ..moveTo(w, h - _arm)
      ..lineTo(w, h - _radius)
      ..quadraticBezierTo(w, h, w - _radius, h)
      ..lineTo(w - _arm, h)
      ..moveTo(_arm, h)
      ..lineTo(_radius, h)
      ..quadraticBezierTo(0, h, 0, h - _radius)
      ..lineTo(0, h - _arm);

    final halo = Paint()
      ..color = const Color(0x99000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final line = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawPath(path, halo)
      ..drawPath(path, line);
  }

  @override
  bool shouldRepaint(_BracketsPainter oldDelegate) => false;
}
