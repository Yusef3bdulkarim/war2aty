import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/document_quad.dart';

// From `Waraqti.dc.html` → `camera`.
const double _bracket = 34;
const double _bracketStroke = 3;

/// How long the guide takes to glide from one detection to the next. Long
/// enough to read as motion rather than a jump, short enough that the guide
/// still feels attached to the paper.
const Duration _followDuration = Duration(milliseconds: 180);

/// The guide drawn on the document the live detector has found (F16).
///
/// There is no static fallback box any more: the frame is *only* ever the
/// detected [quad], gliding toward each new detection rather than snapping,
/// and nothing at all is drawn when there is no detection. The design's mint
/// corner brackets and sweeping scan line follow the paper's own corners, so
/// the brackets turn with it.
///
/// The scan line animates continuously, so any screen showing this must be
/// pumped without `pumpAndSettle` in tests.
///
/// **This guide does not decide what the capture keeps.** The T10 device pass
/// showed the detector collapsing to a sliver often enough that cropping to it
/// discarded most of a real page, and with the static box gone there is no
/// longer anything else to crop to — so the capture keeps the whole frame and
/// `doclens` does the real edge-detect/dewarp on it afterwards.
class ViewfinderFrame extends StatefulWidget {
  const ViewfinderFrame({this.quad, super.key});

  /// The detected document, in fractions of this widget's own box (already
  /// mapped out of sensor space by `FramePreviewMapper`). `null` — no
  /// document, detection off, or detection failed — draws nothing, which is
  /// F16 locked decision #4: the user is never shown a detection failure.
  final DocumentQuad? quad;

  /// Marks the overlay that paints the detected quad, so tests can find it —
  /// and read back the quad actually being drawn this frame — without the
  /// widget having to expose its animation state.
  @visibleForTesting
  static const Key quadOverlayKey = Key('viewfinder-quad-overlay');

  @override
  State<ViewfinderFrame> createState() => _ViewfinderFrameState();
}

class _ViewfinderFrameState extends State<ViewfinderFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _follow = AnimationController(
    vsync: this,
    duration: _followDuration,
  );

  /// Where the guide was when the current glide started, and where it is
  /// heading. Both are `null` while nothing is detected.
  DocumentQuad? _from;
  DocumentQuad? _to;

  @override
  void initState() {
    super.initState();
    _to = widget.quad;
    _from = widget.quad;
    if (widget.quad != null) _follow.value = 1;
  }

  @override
  void didUpdateWidget(ViewfinderFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quad == oldWidget.quad) return;

    // Glide from wherever the guide is right now — mid-animation included —
    // so a detection arriving during a glide does not restart it from a stale
    // position.
    _from = _currentQuad ?? widget.quad;
    _to = widget.quad;
    _follow
      ..value = 0
      ..forward();
  }

  /// The quad as drawn this frame, interpolated between [_from] and [_to].
  ///
  /// A detection dropping out is not handled here: the cubit holds the last
  /// quad through a short grace window (F16-T07) and only then hands over
  /// `null`, so by the time the widget sees `null` the document really is
  /// gone and the guide should disappear.
  DocumentQuad? get _currentQuad {
    final to = _to;
    final from = _from;
    if (to == null) return null;
    if (from == null || _follow.value >= 1) return to;
    return from.lerpTo(to, Curves.easeOut.transform(_follow.value));
  }

  @override
  void dispose() {
    _follow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _follow,
      builder: (context, _) {
        final quad = _currentQuad;
        return quad == null ? const SizedBox.shrink() : _buildQuadOverlay(quad);
      },
    );
  }

  /// The guide sitting on the detected document.
  Widget _buildQuadOverlay(DocumentQuad quad) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();

        final rect = quad.boundingRect;
        // A collapsed detection is drawn as nothing rather than as a sliver.
        if (rect.width <= 0 || rect.height <= 0) return const SizedBox.shrink();

        return Stack(
          key: ViewfinderFrame.quadOverlayKey,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: QuadPainter(
                  quad: quad,
                  mint: AppColors.of(context).mint,
                ),
              ),
            ),
            // The design's scan line, kept inside the detected shape so the
            // motif survives the static box's removal.
            Positioned(
              left: rect.left * size.width,
              top: rect.top * size.height,
              width: rect.width * size.width,
              height: rect.height * size.height,
              child: const _ScanLine(),
            ),
          ],
        );
      },
    );
  }
}

/// Paints the detected document: a faint fill, a hairline outline, and one
/// mint L-bracket at each corner, aligned to that corner's own two edges so
/// the brackets turn with the paper.
///
/// Public only so a widget test can read [quad] back and assert what is
/// actually on screen this frame, mid-glide included.
@visibleForTesting
class QuadPainter extends CustomPainter {
  const QuadPainter({required this.quad, required this.mint});

  final DocumentQuad quad;
  final Color mint;

  @override
  void paint(Canvas canvas, Size size) {
    final corners = [
      for (final p in quad.corners) Offset(p.x * size.width, p.y * size.height),
    ];

    final path = Path()..addPolygon(corners, true);
    canvas
      ..drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.04))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.35),
      );

    final bracketPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketStroke
      ..strokeCap = StrokeCap.round
      ..color = mint;

    for (var i = 0; i < 4; i++) {
      final corner = corners[i];
      final previous = corners[(i + 3) % 4];
      final next = corners[(i + 1) % 4];

      final start = _towards(corner, previous);
      final end = _towards(corner, next);
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(end.dx, end.dy),
        bracketPaint,
      );
    }
  }

  /// A point [_bracket] along the way from [corner] to [target] — or the
  /// midpoint when the edge is shorter than a bracket, so a small quad's
  /// brackets never overshoot into each other.
  static Offset _towards(Offset corner, Offset target) {
    final delta = target - corner;
    final length = delta.distance;
    if (length == 0) return corner;
    final t = math.min(_bracket / length, 0.5);
    return corner + delta * t;
  }

  @override
  bool shouldRepaint(QuadPainter oldDelegate) =>
      oldDelegate.quad != quad || oldDelegate.mint != mint;
}

/// The mint line that sweeps up and down inside the guide.
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
        // -0.9..0.9 keeps the line just inside the guide's corners.
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
