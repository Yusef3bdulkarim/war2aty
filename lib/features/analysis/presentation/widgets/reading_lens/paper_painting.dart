import 'dart:math' as math;
import 'dart:ui';

import '../../../../../core/theme/app_colors.dart';
import 'paper_frame.dart';
import 'paper_layout.dart';

/// Drawing the paper the magnifier reads, in paper units (F22 #18, C+).
///
/// Split into the stack (sheets, shadow, the paper itself), its content, and
/// the marks drawn over the lens (sparkles, review checks), because the lens
/// draws the content a second time, magnified, inside its glass (F22 #4) —
/// the same calls, so the enlarged view is exact.
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
      degrees: -4,
      shift: const Offset(-6, 8),
    );
    _paintSheet(
      canvas,
      colors.surfaceAlt,
      colors,
      degrees: 2.5,
      shift: const Offset(6, 4),
    );
    canvas
      ..drawRRect(
        _paper.shift(const Offset(0, 18)),
        _shadow(colors.ink.withValues(alpha: 0.12), 50),
      )
      ..drawRRect(_paper, Paint()..color = colors.card);
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
    _paintLogo(canvas, colors);
    _bar(canvas, PaperLayout.title, colors.textSecondary);
    _bar(canvas, PaperLayout.subtitle, colors.borderStrong);
    canvas.drawRect(PaperLayout.divider, Paint()..color = colors.borderSoft);

    final field = RRect.fromRectAndRadius(
      PaperLayout.field,
      const Radius.circular(PaperLayout.fieldRadius),
    );
    canvas
      ..drawRRect(
        field,
        Paint()..color = colors.brandPrimary.withValues(alpha: 0.05),
      )
      ..drawRRect(
        field.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = colors.brandPrimary.withValues(alpha: 0.22),
      );

    for (final (i, word) in PaperLayout.words.indexed) {
      final ink = frame.words[i];
      final settled = Color.lerp(colors.border, colors.iconMuted, ink.read)!;
      _bar(
        canvas,
        word.rect,
        Color.lerp(settled, colors.brandPrimary, ink.lit)!,
      );
      _paintUnderline(canvas, word.rect, frame.underlines[i], colors);
    }

    _paintStamp(canvas, colors);
    _bar(canvas, PaperLayout.footer, colors.border);
  }

  /// What is drawn over the lens: the key words' sparkles and the review
  /// checks (F22 #8).
  static void paintMarks(Canvas canvas, PaperFrame frame, AppColors colors) {
    for (final (i, word) in PaperLayout.words.indexed) {
      _paintSparkle(
        canvas,
        PaperLayout.sparkleOf(word.rect),
        frame.sparkles[i],
        colors,
      );
    }
    for (final (line, check) in frame.checks.indexed) {
      if (check.opacity <= 0 || check.scale <= 0) continue;
      paintCheckDisc(
        canvas,
        Offset(
          PaperLayout.checkLeft + PaperLayout.checkSize / 2,
          PaperLayout.lineCentres[line],
        ),
        radius: PaperLayout.checkSize / 2 * check.scale,
        opacity: check.opacity,
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
    // The tick, sized to the disc.
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(radius * 1.25 / _iconBox)
      ..drawPath(
        _tick,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colors.onBrand.withValues(alpha: opacity),
      )
      ..restore();
  }

  /// The design's icons are drawn in a 24-unit box; these are built once,
  /// centred on the origin, and placed and sized by the canvas when drawn.
  static const double _iconBox = 24;

  static final Path _tick = _iconPath([(5, 12.5), (9.5, 17), (19, 7.5)]);

  static final Path _bolt = _iconPath([
    (13, 3),
    (5, 13),
    (11, 13),
    (10, 21),
    (18, 11),
    (12, 11),
  ], close: true);

  static final Path _star = _iconPath([
    (12, 1),
    (14.6, 9.4),
    (23, 12),
    (14.6, 14.6),
    (12, 23),
    (9.4, 14.6),
    (1, 12),
    (9.4, 9.4),
  ], close: true);

  static Path _iconPath(List<(double, double)> points, {bool close = false}) {
    const half = _iconBox / 2;
    final path = Path()..moveTo(points.first.$1 - half, points.first.$2 - half);
    for (final (x, y) in points.skip(1)) {
      path.lineTo(x - half, y - half);
    }
    if (close) path.close();
    return path;
  }

  /// Overshoots a little, then settles: the finish check's spring.
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
        _shadow(colors.ink.withValues(alpha: 0.08), 30),
      )
      ..drawRRect(_paper, Paint()..color = color)
      ..restore();
  }

  /// The letterhead: a pale teal disc with a lightning bolt.
  static void _paintLogo(Canvas canvas, AppColors colors) {
    const logo = PaperLayout.logo;
    canvas.drawOval(
      logo,
      Paint()..color = colors.brandPrimary.withValues(alpha: 0.12),
    );
    // The bolt, drawn 16 wide.
    canvas
      ..save()
      ..translate(logo.center.dx, logo.center.dy)
      ..scale(16 / _iconBox)
      ..drawPath(
        _bolt,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = colors.brandPrimary,
      )
      ..restore();
  }

  /// A faint round stamp, tilted, with an inner ring.
  static void _paintStamp(Canvas canvas, AppColors colors) {
    const stamp = PaperLayout.stamp;
    final ink = colors.error.withValues(alpha: 0.3);
    canvas
      ..save()
      ..translate(stamp.center.dx, stamp.center.dy)
      ..rotate(PaperLayout.stampTiltDegrees * math.pi / 180)
      ..drawCircle(
        Offset.zero,
        stamp.width / 2 - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ink,
      )
      ..drawCircle(
        Offset.zero,
        stamp.width / 2 - 7.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = ink,
      )
      ..restore();
  }

  /// Grows from the word's right edge — the start of an Arabic word.
  static void _paintUnderline(
    Canvas canvas,
    Rect word,
    Underline underline,
    AppColors colors,
  ) {
    if (underline.opacity <= 0 || underline.width <= 0) return;
    final full = PaperLayout.underlineOf(word);
    final width = full.width * underline.width;
    _bar(
      canvas,
      Rect.fromLTWH(full.right - width, full.top, width, full.height),
      colors.mint.withValues(alpha: underline.opacity),
    );
  }

  /// A four-pointed star, bursting and turning.
  static void _paintSparkle(
    Canvas canvas,
    Offset centre,
    Sparkle sparkle,
    AppColors colors,
  ) {
    if (sparkle.opacity <= 0 || sparkle.scale <= 0) return;
    // The star, drawn 18 wide at full size.
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(sparkle.degrees * math.pi / 180)
      ..scale(sparkle.scale * PaperLayout.sparkleSize / _iconBox)
      ..drawPath(
        _star,
        Paint()..color = colors.mint.withValues(alpha: sparkle.opacity),
      )
      ..restore();
  }

  /// A rounded bar: a word, a label, a line.
  static void _bar(Canvas canvas, Rect rect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()..color = color,
    );
  }

  /// A CSS box shadow's blur, [blurRadius] in its own units.
  static Paint _shadow(Color color, double blurRadius) => Paint()
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigma(blurRadius / 2));

  /// The same conversion as [BoxShadow.blurSigma].
  static double _sigma(double radius) => radius * 0.57735 + 0.5;
}
