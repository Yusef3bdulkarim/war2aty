import 'dart:math' as math;
import 'dart:ui';

import '../../../../../core/theme/app_colors.dart';
import 'lens_timeline.dart';
import 'paper_frame.dart';
import 'paper_layout.dart';

/// Drawing the paper the magnifier reads, in paper units.
///
/// Split into the stack (sheets, shadow, the paper itself) and its content,
/// because the lens draws the content a second time, magnified, inside its
/// glass (F22 #4) — the same calls, so the enlarged view is exact.
///
/// Every colour is an [AppColors] token, so the page follows «تباين عالي».
abstract final class PaperPainting {
  static const Radius _corner = Radius.circular(PaperLayout.cornerRadius);

  static final RRect _paper = RRect.fromRectAndRadius(
    Offset.zero & PaperLayout.size,
    _corner,
  );

  /// The two sheets behind the paper, its shadow, and the paper. [finish]
  /// (0 → 1) rings it in green once the result has arrived.
  static void paintStack(Canvas canvas, AppColors colors, {double finish = 0}) {
    _paintSheet(
      canvas,
      colors.bgBase,
      colors,
      degrees: -3.5,
      shift: const Offset(-6, 8),
    );
    _paintSheet(
      canvas,
      colors.surfaceAlt,
      colors,
      degrees: 2,
      shift: const Offset(5, 4),
    );
    canvas.drawRRect(
      _paper.shift(const Offset(0, 18)),
      _shadow(colors.ink.withValues(alpha: 0.12), 25),
    );
    canvas.drawRRect(_paper, Paint()..color = colors.card);
    if (finish > 0) {
      canvas.drawRRect(
        _paper.inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colors.success.withValues(alpha: 0.35 * finish),
      );
    }
  }

  /// Everything printed on the paper, as [frame] says it stands.
  static void paintContent(Canvas canvas, PaperFrame frame, AppColors colors) {
    final fill = Paint();

    // The letterhead.
    canvas.drawOval(
      PaperLayout.logo,
      fill..color = colors.brandPrimary.withValues(alpha: 0.12),
    );
    _paintTitleOutline(canvas, frame.titleOutline, colors);
    _bar(
      canvas,
      PaperLayout.title,
      Color.lerp(colors.textSecondary, colors.brandPrimary, frame.titleLit)!,
    );
    _bar(canvas, PaperLayout.subtitle, colors.borderStrong);
    canvas.drawRect(PaperLayout.divider, fill..color = colors.borderSoft);

    for (final (i, field) in PaperLayout.fields.indexed) {
      _paintField(
        canvas,
        field,
        active: frame.fieldActive[i],
        visited: frame.fieldVisited[i],
        colors: colors,
      );
    }

    for (final (i, word) in PaperLayout.words.indexed) {
      final ink = frame.wordRead[i] ? colors.iconMuted : colors.border;
      _bar(
        canvas,
        word.rect,
        Color.lerp(ink, colors.brandPrimary, frame.wordLit[i])!,
      );
      if (word.isKey) {
        _paintUnderline(canvas, word.rect, frame.keyUnderline, colors);
      }
    }

    for (final line in PaperLayout.footer) {
      _bar(canvas, line, colors.borderSoft);
    }
  }

  /// The review checks, as [frame] says they stand (F22 #8).
  static void paintChecks(Canvas canvas, PaperFrame frame, AppColors colors) {
    for (final (i, check) in LensTimeline.reviewChecks.indexed) {
      final amount = frame.checks[i];
      if (amount <= 0) continue;
      final box = check.topLeft & const Size.square(PaperLayout.checkSize);
      paintCheckDisc(
        canvas,
        box.center,
        radius: PaperLayout.checkSize / 2 * (0.4 + 0.6 * easeOutBack(amount)),
        opacity: amount,
        colors: colors,
      );
    }
  }

  /// A green disc with a white tick: the review checks and the finish check.
  static void paintCheckDisc(
    Canvas canvas,
    Offset centre, {
    required double radius,
    required AppColors colors,
    double opacity = 1,
  }) {
    if (radius <= 0 || opacity <= 0) return;
    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = colors.success.withValues(alpha: opacity),
    );
    // The design's tick, from a 24-unit icon box, sized to the disc.
    final unit = radius * 1.25 / 24;
    final origin = centre - Offset(12 * unit, 12 * unit);
    final tick = Path()
      ..moveTo(origin.dx + 5 * unit, origin.dy + 12.5 * unit)
      ..lineTo(origin.dx + 9.5 * unit, origin.dy + 17 * unit)
      ..lineTo(origin.dx + 19 * unit, origin.dy + 7.5 * unit);
    canvas.drawPath(
      tick,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * unit
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colors.onBrand.withValues(alpha: opacity),
    );
  }

  /// Overshoots a little, then settles: the pop of the outline and checks.
  static double easeOutBack(double u) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(u - 1, 3) + c1 * math.pow(u - 1, 2);
  }

  static double easeOutCubic(double u) => 1 - math.pow(1 - u, 3).toDouble();

  static void _paintSheet(
    Canvas canvas,
    Color color,
    AppColors colors, {
    required double degrees,
    required Offset shift,
  }) {
    final centre = _paper.center;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(degrees * math.pi / 180)
      ..translate(shift.dx - centre.dx, shift.dy - centre.dy)
      ..drawRRect(
        _paper.shift(const Offset(0, 10)),
        _shadow(colors.ink.withValues(alpha: 0.07), 15),
      )
      ..drawRRect(_paper, Paint()..color = color)
      ..restore();
  }

  static void _paintTitleOutline(
    Canvas canvas,
    double amount,
    AppColors colors,
  ) {
    if (amount <= 0) return;
    final scale = 0.85 + 0.15 * easeOutBack(amount);
    const rect = PaperLayout.titleOutline;
    final scaled = Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * scale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaled.deflate(1),
        Radius.circular(scaled.height / 2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.brandPrimary.withValues(alpha: amount),
    );
  }

  static void _paintField(
    Canvas canvas,
    PaperField field, {
    required double active,
    required bool visited,
    required AppColors colors,
  }) {
    final box = RRect.fromRectAndRadius(field.box, const Radius.circular(10));
    canvas.drawRRect(
      box,
      Paint()..color = colors.brandPrimary.withValues(alpha: 0.04),
    );
    if (active > 0) {
      canvas.drawRRect(
        box.inflate(2.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = colors.mint.withValues(alpha: 0.22 * active),
      );
    }
    final resting = colors.brandPrimary.withValues(alpha: visited ? 0.45 : 0.2);
    canvas.drawRRect(
      box.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(resting, colors.brandPrimary, active)!,
    );
    _bar(canvas, field.label, colors.borderStrong);
  }

  /// Grows from the word's right edge — the start of an Arabic word.
  static void _paintUnderline(
    Canvas canvas,
    Rect word,
    double amount,
    AppColors colors,
  ) {
    if (amount <= 0) return;
    final width = word.width * easeOutCubic(amount);
    _bar(
      canvas,
      Rect.fromLTWH(word.right - width, word.top + 16, width, 4),
      colors.mint,
    );
  }

  /// A rounded bar: a word, a label, a line.
  static void _bar(Canvas canvas, Rect rect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()..color = color,
    );
  }

  static Paint _shadow(Color color, double blurRadius) => Paint()
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigma(blurRadius));

  /// The same conversion as [BoxShadow.blurSigma].
  static double _sigma(double radius) => radius * 0.57735 + 0.5;
}
