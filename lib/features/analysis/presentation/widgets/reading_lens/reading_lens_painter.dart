import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../../core/theme/app_colors.dart';
import 'lens_timeline.dart';
import 'paper_layout.dart';
import 'paper_painting.dart';
import 'scene_frame.dart';

/// Paints the scene [scene] holds, repainting whenever it changes — which is
/// every frame while the lens moves, without rebuilding a single widget.
///
/// Draws in paper units, scaled to the size it is given (the paper's
/// proportions). The lens, its handle and the rings reach outside that box;
/// nothing above clips them.
class ReadingLensPainter extends CustomPainter {
  ReadingLensPainter({required this.scene, required this.colors})
    : super(repaint: scene);

  final ValueListenable<SceneFrame> scene;
  final AppColors colors;

  /// The lens's radius, in paper units, and its magnification (F22 #4).
  static const double lensRadius = 52;
  static const double magnification = 1.7;

  static const double _checkRadius = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = scene.value;
    canvas
      ..save()
      ..scale(size.width / PaperLayout.size.width);

    final entering = frame.paperOpacity < 1;
    if (entering) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, frame.paperOpacity),
      );
    }
    canvas.translate(0, frame.paperRise);

    PaperPainting.paintStack(canvas, colors, finish: frame.finishRing);
    PaperPainting.paintContent(canvas, frame.paper, colors);
    if (frame.lensOpacity > 0 && frame.lensScale > 0) _paintLens(canvas, frame);
    PaperPainting.paintChecks(canvas, frame.paper, colors);
    _paintFinishCheck(canvas, frame);

    if (entering) canvas.restore();
    canvas.restore();
  }

  void _paintLens(Canvas canvas, SceneFrame frame) {
    canvas
      ..save()
      ..translate(frame.lens.dx, frame.lens.dy)
      ..scale(frame.lensScale);
    final fading = frame.lensOpacity < 1;
    if (fading) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, frame.lensOpacity),
      );
    }

    // Its shadow on the paper, below and to the right.
    canvas.drawCircle(
      const Offset(18, 26),
      lensRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                colors.ink.withValues(alpha: 0.15),
                colors.ink.withValues(alpha: 0),
              ],
              stops: const [0, 0.66],
            ).createShader(
              Rect.fromCircle(center: const Offset(18, 26), radius: lensRadius),
            ),
    );

    _paintHandle(canvas, frame.handleDegrees);

    // The halo that lifts the glass off the page.
    canvas
      ..drawCircle(
        const Offset(0, 10),
        lensRadius,
        Paint()
          ..color = colors.brandDeep.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.5),
      )
      ..drawCircle(
        Offset.zero,
        lensRadius,
        Paint()
          ..color = colors.mint.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.5),
      );

    _paintGlass(canvas, frame);

    // The rim.
    canvas
      ..drawCircle(
        Offset.zero,
        lensRadius + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colors.card.withValues(alpha: 0.8),
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

  /// The handle trails from the rim down to the right, swinging with the
  /// lens's movement; only the handle swings, never the glass.
  void _paintHandle(Canvas canvas, double swingDegrees) {
    canvas
      ..save()
      ..rotate((-45 + swingDegrees) * math.pi / 180)
      ..drawRRect(
        RRect.fromLTRBR(-10, 44, 10, 56, const Radius.circular(4)),
        Paint()..color = colors.brandDeep,
      );
    const grip = Rect.fromLTWH(-7, 54, 14, 50);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(grip, const Radius.circular(7)),
        Paint()
          ..shader = LinearGradient(
            colors: [colors.brandPrimary, colors.brandDeep],
          ).createShader(grip),
      )
      ..restore();
  }

  /// The magnified paper under the glass: the same content, drawn again at
  /// ×[magnification] around the lens centre, clipped to the circle.
  void _paintGlass(Canvas canvas, SceneFrame frame) {
    final glass = Rect.fromCircle(center: Offset.zero, radius: lensRadius);
    canvas
      ..save()
      ..clipPath(Path()..addOval(glass))
      ..drawRect(glass, Paint()..color = colors.card)
      ..save()
      ..scale(magnification)
      ..translate(-frame.lens.dx, -frame.lens.dy);
    PaperPainting.paintContent(canvas, frame.paper, colors);
    canvas
      ..restore()
      // A faint mint tint, and the glass's edge darkening inwards.
      ..drawRect(glass, Paint()..color = colors.mint.withValues(alpha: 0.07))
      ..drawRect(
        glass,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors.brandDeep.withValues(alpha: 0),
              colors.brandDeep.withValues(alpha: 0.26),
            ],
            stops: const [0.72, 1],
          ).createShader(glass),
      )
      ..drawCircle(
        Offset.zero,
        lensRadius - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.mint.withValues(alpha: 0.25),
      );

    if (frame.glint case final glint?) {
      // A slanted streak of light, crossing from left to right.
      final x = -90 + 230 * glint - 38;
      const streak = Rect.fromLTWH(-14, -86, 28, 172);
      canvas
        ..save()
        ..translate(x, 0)
        ..rotate(25 * math.pi / 180)
        ..drawRect(
          streak,
          Paint()
            ..shader = LinearGradient(
              colors: [
                colors.card.withValues(alpha: 0),
                colors.card.withValues(alpha: 0.6),
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
      canvas.drawCircle(
        centre,
        _checkRadius * (1 + 1.3 * ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colors.success.withValues(alpha: 0.6 * (1 - ring)),
      );
    }
    if (frame.check <= 0) return;
    canvas.drawCircle(
      centre + const Offset(0, 10),
      _checkRadius * frame.check,
      Paint()
        ..color = colors.success.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.4),
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
