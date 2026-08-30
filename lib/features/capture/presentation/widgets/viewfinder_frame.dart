import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/document_quad.dart';

// From `Waraqti.dc.html` → `camera`.
const double _frameRadius = 14;
const double _bracket = 34;
const double _bracketStroke = 3;

/// How long the guide takes to glide from one detection to the next. Long
/// enough to read as motion rather than a jump, short enough that the guide
/// still feels attached to the paper.
const Duration _followDuration = Duration(milliseconds: 180);

/// The dashed guide the user lines the paper up inside, with mint corner
/// brackets and a sweeping scan line.
///
/// Signals "hold it here" — the camera screen (F15) measures this box's real
/// on-screen position at capture time and crops to it (with a safety
/// margin), so what's kept is (approximately) what was framed. The scan line
/// animates continuously, so any screen showing it must be pumped without
/// `pumpAndSettle` in tests.
///
/// When [quad] is given (F16), the guide leaves the middle of the screen and
/// follows the detected document instead, gliding toward each new detection
/// rather than snapping. `null` — no document, detection off, or detection
/// failed — falls back to the static responsive box above, which is F16
/// locked decision #4: the user is never shown a detection failure, only
/// today's behaviour.
class ViewfinderFrame extends StatefulWidget {
  const ViewfinderFrame({required this.frameKey, this.quad, super.key});

  /// Goes on the guide box itself, so the camera screen measures the rect
  /// that is actually on screen instead of recomputing it from constants —
  /// the crop then follows the frame to whatever size it resolves to.
  ///
  /// When a [quad] is being shown this rides on **the drawn quad's bounding
  /// box**, which is what makes the capture crop follow the visible guide
  /// (F16-T08) without a second geometry path.
  final GlobalKey frameKey;

  /// The detected document, in fractions of this widget's own box (already
  /// mapped out of sensor space by `FramePreviewMapper`).
  final DocumentQuad? quad;

  // ── The design's own numbers, from `Waraqti.dc.html` → `camera` ──
  //
  // A 290×380 guide box on a 368 pt-wide screen (a 390×844 device mock with
  // an 11 pt bezel). They are kept as *ratios* rather than absolute sizes so
  // the framing is the same share of the preview on every phone, instead of
  // crowding the edges of a small screen and shrinking into the middle of a
  // large one. The 290:380 proportions themselves are unchanged — a different
  // paper aspect would be a design decision, not a layout one.

  static const double _designScreenWidth = 368;
  static const double _designWidth = 290;
  static const double _designHeight = 380;

  /// The guide box's width as a share of the preview's width.
  static const double widthFactor = _designWidth / _designScreenWidth;

  /// The guide box's width ÷ height.
  static const double aspectRatio = _designWidth / _designHeight;

  /// The largest box with the design's proportions that fits inside [available]
  /// — normally bound by [widthFactor], and by the height on a short screen.
  static Size resolveSize(Size available) {
    final width = math.min(
      available.width * widthFactor,
      available.height * aspectRatio,
    );
    return Size(width, width / aspectRatio);
  }

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
  /// heading. Both are `null` while the static box is showing.
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
  /// gone and the guide should return to its static box.
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
        return quad == null ? _buildStaticBox() : _buildQuad(quad);
      },
    );
  }

  /// F15-T12's responsive centred box — the behaviour F16 falls back to.
  Widget _buildStaticBox() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ViewfinderFrame.resolveSize(constraints.biggest);
        return Center(
          child: SizedBox(
            key: widget.frameKey,
            width: size.width,
            height: size.height,
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
      },
    );
  }

  /// The guide sitting on the detected document: the same faint field, the
  /// same mint brackets and the same scan line as the static box, but drawn
  /// on the paper's real corners so the brackets rotate with it.
  Widget _buildQuad(DocumentQuad quad) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return _buildStaticBox();

        final rect = quad.boundingRect;
        final left = rect.left * size.width;
        final top = rect.top * size.height;
        final width = (rect.right - rect.left) * size.width;
        final height = (rect.bottom - rect.top) * size.height;
        // Degenerate detections are drawn as nothing rather than as a sliver;
        // the crop guards the same case independently (F16-T08).
        if (width <= 0 || height <= 0) return _buildStaticBox();

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _QuadPainter(
                  quad: quad,
                  mint: AppColors.of(context).mint,
                ),
              ),
            ),
            // The bounding box the capture crop measures. It carries no paint
            // of its own — the painter above draws the real shape — but it is
            // what `_measureGuideBox` reads, so the crop follows the guide
            // the user actually saw (F16-T08).
            Positioned(
              left: left,
              top: top,
              width: width,
              height: height,
              child: SizedBox(key: widget.frameKey, child: const _ScanLine()),
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
class _QuadPainter extends CustomPainter {
  const _QuadPainter({required this.quad, required this.mint});

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
  bool shouldRepaint(_QuadPainter oldDelegate) =>
      oldDelegate.quad != quad || oldDelegate.mint != mint;
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
