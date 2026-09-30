import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../../core/theme/app_colors.dart';
import 'lens_timeline.dart';
import 'paper_layout.dart';
import 'paper_painting.dart';
import 'scene_frame.dart';

/// Paints the scene [scene] holds, repainting whenever it changes — which is
/// every frame while the lens moves, without rebuilding a single widget
/// (F22 #18, the C+ design).
///
/// Draws in paper units, scaled to the size it is given (the paper's
/// proportions). The light, the lens, its handle and the rings reach outside
/// that box; nothing above clips them.
class ReadingLensPainter extends CustomPainter {
  ReadingLensPainter({required this.scene, required this.colors})
    : super(repaint: scene);

  final ValueListenable<SceneFrame> scene;
  final AppColors colors;

  /// The lens's radius, in paper units, and its magnification (F22 #4).
  static const double lensRadius = 48;
  static const double magnification = 1.7;

  static const double _spotlightRadius = 230;
  static const double _checkRadius = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = scene.value;
    canvas
      ..save()
      ..scale(size.width / PaperLayout.size.width)
      // Everything floats together: the light, the paper, the lens.
      ..translate(0, frame.paperFloat);

    _paintSpotlight(canvas, frame);
    PaperPainting.paintStack(canvas, colors, finish: frame.settled);
    PaperPainting.paintContent(canvas, frame.paper, colors);
    if (frame.lensOpacity > 0) _paintLens(canvas, frame);
    PaperPainting.paintMarks(canvas, frame.paper, colors);
    _paintFinishCheck(canvas, frame);

    canvas.restore();
  }

  /// A soft light behind the paper that follows the lens, turning green
  /// once the result has arrived.
  void _paintSpotlight(Canvas canvas, SceneFrame frame) {
    final centre = LensTimeline.centre + frame.spotlight;
    final light = Color.lerp(colors.mint, colors.success, frame.settled)!;
    final area = Rect.fromCircle(center: centre, radius: _spotlightRadius);
    canvas.drawRect(
      area,
      Paint()
        ..shader = RadialGradient(
          colors: [light.withValues(alpha: 0.22), light.withValues(alpha: 0)],
          stops: const [0, 0.62],
        ).createShader(area),
    );
  }

  void _paintLens(Canvas canvas, SceneFrame frame) {
    final centre = frame.lens + Offset(0, frame.lensBob);
    canvas
      ..save()
      ..translate(centre.dx, centre.dy);
    final fading = frame.lensOpacity < 1;
    if (fading) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, frame.lensOpacity),
      );
    }

    // Its shadow on the paper, below and to the right.
    const shadowCentre = Offset(22, 30);
    canvas.drawCircle(
      shadowCentre,
      lensRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                colors.ink.withValues(alpha: 0.16),
                colors.ink.withValues(alpha: 0),
              ],
              stops: const [0, 0.65],
            ).createShader(
              Rect.fromCircle(center: shadowCentre, radius: lensRadius),
            ),
    );

    _paintHandle(canvas);

    // The halo that lifts the glass off the page.
    canvas
      ..drawCircle(
        const Offset(0, 10),
        lensRadius,
        Paint()
          ..color = colors.brandDeep.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawCircle(
        Offset.zero,
        lensRadius,
        Paint()
          ..color = colors.mint.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.6),
      );

    _paintGlass(canvas, frame, centre);

    // The rim: a white edge, then the teal ring.
    canvas
      ..drawCircle(
        Offset.zero,
        lensRadius + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colors.card.withValues(alpha: 0.75),
      )
      ..drawCircle(
        Offset.zero,
        lensRadius - 2.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = colors.brandPrimary,
      );

    if (fading) canvas.restore();
    canvas.restore();
  }

  /// The handle leaves the rim at the lower right, slanting down and away.
  void _paintHandle(Canvas canvas) {
    const grip = Rect.fromLTWH(-7, 0, 14, 50);
    canvas
      ..save()
      ..translate(35, 30)
      ..rotate(-45 * math.pi / 180)
      ..drawRRect(
        RRect.fromRectAndRadius(grip, const Radius.circular(7)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.brandPrimary, colors.brandDeep],
          ).createShader(grip),
      )
      ..restore();
  }

  /// The magnified paper under the glass: the same content, drawn again at
  /// ×[magnification] around the lens centre, clipped to the circle.
  void _paintGlass(Canvas canvas, SceneFrame frame, Offset centre) {
    final glass = Rect.fromCircle(center: Offset.zero, radius: lensRadius);
    canvas
      ..save()
      ..clipPath(Path()..addOval(glass))
      ..drawRect(glass, Paint()..color = colors.card)
      ..save()
      ..scale(magnification)
      ..translate(-centre.dx, -centre.dy);
    PaperPainting.paintContent(canvas, frame.paper, colors);
    canvas
      ..restore()
      // A faint mint tint, and the glass's edge darkening inwards.
      ..drawRect(glass, Paint()..color = colors.mint.withValues(alpha: 0.08))
      ..drawRect(
        glass,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors.brandDeep.withValues(alpha: 0),
              colors.brandDeep.withValues(alpha: 0.28),
            ],
            stops: const [0.72, 1],
          ).createShader(glass),
      );

    if (frame.glint case final glint?) {
      // A slanted streak of light, crossing from left to right.
      final x = 13 - 80 + 210 * glint - lensRadius;
      const streak = Rect.fromLTWH(-13, -80, 26, 160);
      canvas
        ..save()
        ..translate(x, 2)
        ..rotate(25 * math.pi / 180)
        ..drawRect(
          streak,
          Paint()
            ..shader = LinearGradient(
              colors: [
                colors.card.withValues(alpha: 0),
                colors.card.withValues(alpha: 0.65),
                colors.card.withValues(alpha: 0),
              ],
            ).createShader(streak),
        )
        ..restore();
    }
    canvas.restore();
  }

  void _paintFinishCheck(Canvas canvas, SceneFrame frame) {
    const centre = LensTimeline.centre;
    if (frame.checkRing case final ring?) {
      final spread = PaperPainting.easeOutCubic(ring);
      canvas.drawCircle(
        centre,
        _checkRadius * (1 + 1.2 * spread),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colors.success.withValues(alpha: 0.6 * (1 - spread)),
      );
    }
    if (frame.check <= 0) return;
    canvas.drawCircle(
      centre + const Offset(0, 10),
      _checkRadius * frame.check,
      Paint()
        ..color = colors.success.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.4),
    );
    PaperPainting.paintCheckDisc(
      canvas,
      centre,
      radius: _checkRadius * frame.check,
      colors: colors,
    );
  }

  @override
  bool shouldRepaint(ReadingLensPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.colors != colors;
}
