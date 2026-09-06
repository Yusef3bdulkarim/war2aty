import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Vector redraw of the War2aty app icon, animated as a paper plane that glides
/// in and unfolds into the document + magnifier mark.
///
/// The static PNG icon cannot be animated part by part, so the mark is authored
/// here as paths in a 100×100 design space and scaled to [size]. The silhouette
/// is a morph between a folded paper dart and the sheet: both outlines are
/// sampled into the same number of points by arc length, then lerped, which
/// makes the plane literally open up into the page.
///
/// Entrance timeline (fractions of [progress]):
///   0.00 → 0.60  the dart glides in from off the top-left corner, growing
///   0.58 → 0.72  it unfolds into the sheet the moment it lands
///   0.68 → 0.88  the sheet's lines write themselves in, right to left
///   0.71 → 0.83  the magnifier drops in with an elastic bounce
///   0.73 → 0.92  the orbit rings draw themselves
///   0.82 → 0.97  a scan beam sweeps down the page
///
/// The splash is held for at least [kLogoEntranceDuration] so the mark is never
/// cut off mid-flight when the launch sequence finishes early.
class PaperPlaneLogo extends StatelessWidget {
  const PaperPlaneLogo({
    super.key,
    required this.progress,
    required this.ambient,
    this.size = 150,
  });

  /// Entrance progress, 0 → 1.
  final double progress;

  /// Ambient loop phase, 0 → 1, looping once the entrance has finished.
  final double ambient;

  /// Side of the logo itself. The box only has to hold the settled mark and its
  /// orbit rings — the flight path deliberately starts outside it, and the
  /// painter does not clip.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.15,
      height: size * 1.15,
      child: CustomPaint(
        painter: _PaperPlanePainter(
          progress: progress,
          ambient: ambient,
          logoSize: size,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Palette — the icon's own colours, independent of the app theme.
// ---------------------------------------------------------------------------

const Color _kPaperLight = Color(0xFFFBF9F3);
const Color _kPaperDark = Color(0xFFE4E0D3);
const Color _kFlap = Color(0xFFD8D3C4);
const Color _kInk = Color(0xFF2A7C87);
const Color _kLine = Color(0xFF8B9AA2);
const Color _kGlassLine = Color(0xFF7BF2D8);
const Color _kTeal = Color(0xFF0E7C86);
const Color _kDeepTeal = Color(0xFF0A5C64);
const Color _kMint = Color(0xFF34D0B4);

/// Resting tilt of the sheet, matching the icon's slightly leaning page.
const double _kRestTilt = -0.06;

// ---------------------------------------------------------------------------
// Design-space geometry (100×100)
// ---------------------------------------------------------------------------

const double _kSheetL = 24;
const double _kSheetR = 76;
const double _kSheetT = 12;
const double _kSheetB = 90;
const double _kFold = 17;

/// The sheet: a portrait page with a dog-eared top-right corner. Authored
/// clockwise from the fold tip so it morphs against the dart without twisting.
Path _buildSheetPath() {
  const double r = 5;
  return Path()
    ..moveTo(_kSheetR, _kSheetT + _kFold)
    ..lineTo(_kSheetR, _kSheetB - r)
    ..quadraticBezierTo(_kSheetR, _kSheetB, _kSheetR - r, _kSheetB)
    ..lineTo(_kSheetL + r, _kSheetB)
    ..quadraticBezierTo(_kSheetL, _kSheetB, _kSheetL, _kSheetB - r)
    ..lineTo(_kSheetL, _kSheetT + r)
    ..quadraticBezierTo(_kSheetL, _kSheetT, _kSheetL + r, _kSheetT)
    ..lineTo(_kSheetR - _kFold, _kSheetT)
    // `close` draws the diagonal cut of the dog-ear back to the fold tip.
    ..close();
}

/// The folded dart, nose to the right. Same winding as the sheet, and its nose
/// starts where the sheet's fold tip does so the nose becomes the dog-ear.
Path _buildPlanePath() {
  return Path()
    ..moveTo(95, 50) // nose
    ..lineTo(10, 80) // lower wing tip
    ..lineTo(36, 50) // tail notch
    ..lineTo(10, 20) // upper wing tip
    ..close();
}

/// Number of points both outlines are resampled to before lerping.
const int _kMorphPoints = 128;

List<Offset> _samplePath(Path path) {
  final metric = path.computeMetrics().first;
  final length = metric.length;
  return List<Offset>.generate(_kMorphPoints, (i) {
    final tangent = metric.getTangentForOffset(length * i / _kMorphPoints);
    return tangent?.position ?? Offset.zero;
  });
}

// Lazily sampled once, then only lerped per frame.
final List<Offset> _sheetPoints = _samplePath(_buildSheetPath());
final List<Offset> _planePoints = _samplePath(_buildPlanePath());

/// The silhouette at [t]: 0 = folded dart, 1 = flat sheet.
Path _morphedOutline(double t) {
  final path = Path();
  for (var i = 0; i < _kMorphPoints; i++) {
    final p = Offset.lerp(_planePoints[i], _sheetPoints[i], t)!;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

// ---------------------------------------------------------------------------
// Flight path — control points as fractions of the logo size.
// ---------------------------------------------------------------------------

/// Far outside the top-left corner of any phone: the mark sits roughly a third
/// of the way down the screen, so 2.3–2.5 logo-widths up and left clears the
/// corner on every size we support. The painter does not clip, so the dart is
/// simply invisible until it crosses the edge.
const Offset _kFlightFrom = Offset(-2.30, -2.50);
const Offset _kFlightC1 = Offset(-1.15, -1.35);
const Offset _kFlightC2 = Offset(0.45, 0.30);
const Offset _kFlightTo = Offset.zero;

Offset _flightAt(double t, double size) {
  final u = 1 - t;
  final p =
      _kFlightFrom * (u * u * u) +
      _kFlightC1 * (3 * u * u * t) +
      _kFlightC2 * (3 * u * t * t) +
      _kFlightTo * (t * t * t);
  // Paper bobs on the air; the flutter dies out as it lands.
  final bob = math.sin(t * math.pi * 3) * 0.045 * (1 - t);
  return Offset(p.dx * size, (p.dy + bob) * size);
}

/// Bank angle: nose pitched down along the dive out of the corner, easing off
/// as the descent flattens, then flaring level.
double _flightAngle(double t) {
  if (t < 0.55) {
    final f = Curves.easeInOut.transform(t / 0.55);
    return 0.70 + (0.30 - 0.70) * f;
  }
  final f = Curves.easeOutBack.transform((t - 0.55) / 0.45);
  return 0.30 + (_kRestTilt - 0.30) * f;
}

/// Progress of [v] inside the window [a, b], eased by [curve].
double _seg(double v, double a, double b, [Curve curve = Curves.linear]) =>
    curve.transform((((v - a) / (b - a)).clamp(0.0, 1.0)));

double _alpha(double v) => v.clamp(0.0, 1.0);

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _PaperPlanePainter extends CustomPainter {
  _PaperPlanePainter({
    required this.progress,
    required this.ambient,
    required this.logoSize,
  });

  final double progress;
  final double ambient;
  final double logoSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final k = logoSize / 100;

    // Raw flight fraction drives how near the dart reads; the eased one drives
    // where it is. Keeping them apart lets it grow steadily all the way in
    // instead of snapping to full size the moment it stops travelling.
    //
    // easeOutQuad rather than a cubic: the gentler deceleration keeps the glide
    // even instead of rushing the entrance and then crawling to the centre.
    final flightRaw = _seg(progress, 0.0, 0.60);
    final flightT = Curves.easeOutQuad.transform(flightRaw);
    final unfold = _seg(progress, 0.58, 0.72, Curves.easeInOutCubic);
    final glassT = _seg(progress, 0.71, 0.83);
    final ringT = _seg(progress, 0.73, 0.92, Curves.easeOut);
    final scanT = _seg(progress, 0.82, 0.97, Curves.easeInOut);

    // Once landed the whole mark breathes on the ambient loop.
    final settled = _seg(progress, 0.72, 1.0);
    final breathe =
        math.sin(ambient * math.pi * 2) * 1.6 * settled * (logoSize / 150);
    final markCenter = center.translate(0, breathe);

    _paintRing(canvas, markCenter, ringT, front: false);

    // ── The paper: flies in from far off, growing, then unfolds ──
    final flight = _flightAt(flightT, logoSize);
    final scale = 0.22 + 0.78 * Curves.easeInOutCubic.transform(flightRaw);

    canvas.save();
    canvas.translate(markCenter.dx + flight.dx, markCenter.dy + flight.dy);
    canvas.rotate(_flightAngle(flightT));
    canvas.scale(scale * k);
    canvas.translate(-50, -50);
    _paintPaper(canvas, unfold, scanT);
    canvas.restore();

    _paintTrail(canvas, markCenter, flightT);

    // ── The magnifier: drawn upright, above the leaning page ──
    if (glassT > 0) {
      canvas.save();
      canvas.translate(markCenter.dx, markCenter.dy);
      canvas.scale(k);
      canvas.translate(-50, -50);
      _paintMagnifier(canvas, glassT);
      canvas.restore();
    }

    _paintRing(canvas, markCenter, ringT, front: true);
  }

  // ── Paper ───────────────────────────────────────────────────────────────

  void _paintPaper(Canvas canvas, double unfold, double scanT) {
    final outline = _morphedOutline(unfold);

    canvas.drawShadow(outline, Colors.black, 3.5 + 2.5 * unfold, false);
    canvas.drawPath(
      outline,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(_kSheetL, _kSheetT),
          const Offset(_kSheetR, _kSheetB),
          const [_kPaperLight, _kPaperDark],
        ),
    );

    // Everything below lives on the page, so it can never escape the outline.
    canvas.save();
    canvas.clipPath(outline);

    if (unfold < 1) {
      _paintFolds(canvas, unfold);
    }
    if (unfold > 0.55) {
      _paintFlap(canvas, unfold);
      _paintContent(canvas, unfold);
      if (scanT > 0 && scanT < 1) {
        _paintScanBeam(canvas, scanT);
      }
    }

    canvas.restore();
  }

  /// Crease lines and the shaded far wing, both only while it is still folded.
  void _paintFolds(Canvas canvas, double unfold) {
    final fade = _alpha(1 - unfold / 0.75);
    if (fade <= 0) return;

    canvas.drawPath(
      Path()
        ..moveTo(95, 50)
        ..lineTo(10, 80)
        ..lineTo(36, 50)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.10 * fade),
    );

    final crease = Paint()
      ..color = _kFlap.withValues(alpha: 0.95 * fade)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(95, 50), const Offset(36, 50), crease)
      ..drawLine(const Offset(95, 50), const Offset(20, 33), crease)
      ..drawLine(const Offset(95, 50), const Offset(20, 67), crease);
  }

  /// The dog-eared corner, folded down onto the page.
  void _paintFlap(Canvas canvas, double unfold) {
    final t = _alpha((unfold - 0.55) / 0.45);
    canvas.drawPath(
      Path()
        ..moveTo(_kSheetR - _kFold, _kSheetT)
        ..lineTo(_kSheetR, _kSheetT + _kFold)
        ..lineTo(_kSheetR - _kFold, _kSheetT + _kFold)
        ..close(),
      Paint()..color = _kFlap.withValues(alpha: t),
    );
  }

  /// Title bar, body lines and the closing block, each writing itself in from
  /// the right edge — the direction the page is actually read in.
  void _paintContent(Canvas canvas, double unfold) {
    const double right = 68;
    const rows = <_Row>[
      _Row(top: 27, height: 8, width: 32, color: _kInk, radius: 4),
      _Row(top: 41, height: 4.4, width: 36, color: _kLine, radius: 2.2),
      _Row(top: 49, height: 4.4, width: 36, color: _kLine, radius: 2.2),
      _Row(top: 57, height: 4.4, width: 30, color: _kLine, radius: 2.2),
      _Row(top: 65, height: 4.4, width: 36, color: _kLine, radius: 2.2),
      _Row(top: 74, height: 9, width: 18, color: _kLine, radius: 3),
    ];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final start = 0.68 + i * 0.022;
      final t = _seg(progress, start, start + 0.09, Curves.easeOutCubic);
      if (t <= 0) continue;

      final alpha = row.color == _kLine ? 0.85 : 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            right - row.width * t,
            row.top,
            row.width * t,
            row.height,
          ),
          Radius.circular(row.radius),
        ),
        Paint()..color = row.color.withValues(alpha: alpha),
      );
    }
  }

  /// A single mint beam running down the page, as if it were being read.
  void _paintScanBeam(Canvas canvas, double scanT) {
    final y = _kSheetT + (_kSheetB - _kSheetT) * scanT;
    final fade = math.sin(scanT * math.pi);
    canvas.drawRect(
      Rect.fromLTRB(_kSheetL, y - 5, _kSheetR, y + 5),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(_kSheetL, y - 5),
          Offset(_kSheetR, y + 5),
          [
            _kMint.withValues(alpha: 0),
            _kMint.withValues(alpha: _alpha(0.8 * fade)),
            _kMint.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        )
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
    );
  }

  // ── Trail ───────────────────────────────────────────────────────────────

  /// Tapering light trail along the stretch of flight path just travelled.
  void _paintTrail(Canvas canvas, Offset center, double flightT) {
    if (flightT <= 0 || flightT >= 1) return;

    const int segments = 24;
    const double span = 0.22;
    final from = math.max(0.0, flightT - span);
    final unit = logoSize / 150;
    final paint = Paint()..strokeCap = StrokeCap.round;

    var prev = center + _flightAt(from, logoSize);
    for (var i = 1; i <= segments; i++) {
      final f = i / segments;
      final next = center + _flightAt(from + (flightT - from) * f, logoSize);
      final taper = f * f;
      paint
        ..color = _kMint.withValues(alpha: _alpha(0.45 * taper * (1 - flightT)))
        ..strokeWidth = (0.6 + 3.4 * taper) * unit
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 2 * unit);
      canvas.drawLine(prev, next, paint);
      prev = next;
    }
  }

  // ── Magnifier ───────────────────────────────────────────────────────────

  void _paintMagnifier(Canvas canvas, double t) {
    // Low and to the right, so the title bar and the left half of every line
    // stay readable behind it.
    const Offset lens = Offset(65, 66);
    const double radius = 21;
    // 45° down-right, where the handle leaves the ring.
    const double diag = math.sqrt1_2;

    final pop = const ElasticOutCurve(0.9).transform(t.clamp(0.0, 1.0));
    final scale = 1.7 - 0.7 * pop;
    final fade = _alpha(t / 0.35);
    final pulse = 0.75 + 0.25 * math.sin(ambient * math.pi * 2);

    canvas.save();
    canvas.translate(lens.dx, lens.dy);
    canvas.scale(scale);
    canvas.rotate(0.28 * (1 - pop));
    canvas.translate(-lens.dx, -lens.dy);

    // Outer glow.
    canvas.drawCircle(
      lens,
      radius * 1.1,
      Paint()
        ..color = _kMint.withValues(alpha: _alpha(0.34 * fade * pulse))
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
    );

    // The glass casts onto the page it is held over.
    canvas.drawCircle(
      lens.translate(2, 4),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: _alpha(0.22 * fade))
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );

    // Handle, behind the ring so the ring caps it cleanly.
    canvas.drawLine(
      lens + const Offset(diag, diag) * (radius - 3),
      lens + const Offset(diag, diag) * (radius + 15),
      Paint()
        ..color = _kDeepTeal.withValues(alpha: fade)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    // Glass — dark enough that the lines read through it.
    canvas.drawCircle(
      lens,
      radius - 3,
      Paint()
        ..shader = ui.Gradient.radial(lens - const Offset(7, 8), radius * 1.7, [
          const Color(0xFF10606B).withValues(alpha: 0.92 * fade),
          _kDeepTeal.withValues(alpha: 0.98 * fade),
        ]),
    );

    _paintLensContent(canvas, lens, fade * pulse);

    // Ring.
    canvas.drawCircle(
      lens,
      radius - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..shader = ui.Gradient.linear(
          lens - const Offset(radius, radius),
          lens + const Offset(radius, radius),
          [
            const Color(0xFF4FBAC6).withValues(alpha: fade),
            _kDeepTeal.withValues(alpha: fade),
          ],
        ),
    );

    // Specular highlight on the glass.
    canvas.save();
    canvas.translate(lens.dx, lens.dy);
    canvas.rotate(-0.7);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 30),
      math.pi * 0.60,
      math.pi * 0.52,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: _alpha(0.5 * fade)),
    );
    canvas.restore();

    canvas.restore();
  }

  /// The glowing lines and scan brackets seen through the glass.
  void _paintLensContent(Canvas canvas, Offset lens, double fade) {
    final line = Paint()
      ..color = _kGlassLine.withValues(alpha: _alpha(fade))
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.solid, 1.4);
    for (var i = 0; i < 3; i++) {
      final width = i == 2 ? 13.0 : 19.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lens.dx + 9.5 - width, lens.dy - 8.5 + i * 7, width, 4),
          const Radius.circular(2),
        ),
        line,
      );
    }

    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = _kGlassLine.withValues(alpha: _alpha(0.8 * fade));
    const double b = 13;
    const double arm = 4.5;
    for (final corner in const [
      Offset(-b, -b),
      Offset(b, -b),
      Offset(-b, b),
      Offset(b, b),
    ]) {
      final sx = corner.dx.sign;
      final sy = corner.dy.sign;
      final origin = lens + corner;
      canvas
        ..drawLine(origin, origin.translate(-sx * arm, 0), bracket)
        ..drawLine(origin, origin.translate(0, -sy * arm), bracket);
    }
  }

  // ── Orbit rings ─────────────────────────────────────────────────────────

  /// The mint swooshes orbiting the mark: one arc behind it, one in front.
  void _paintRing(
    Canvas canvas,
    Offset center,
    double t, {
    required bool front,
  }) {
    if (t <= 0) return;

    final spin = ambient * math.pi * 2 * (front ? 1 : -1) * 0.12;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: logoSize * 1.06,
      height: logoSize * 0.50,
    );
    final start = (front ? -0.7 : math.pi - 0.7) + spin;
    final sweep = math.pi * 1.05 * t;
    final unit = logoSize / 150;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.30);

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * unit
        ..strokeCap = StrokeCap.round
        ..color = _kMint.withValues(alpha: _alpha(0.55 * t))
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 8 * unit),
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * unit
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          rect.centerLeft,
          rect.centerRight,
          [
            _kMint.withValues(alpha: 0),
            const Color(0xFF9CFFE8).withValues(alpha: _alpha(t)),
            _kTeal.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperPlanePainter old) =>
      old.progress != progress ||
      old.ambient != ambient ||
      old.logoSize != logoSize;
}

/// One drawn row of "text" on the page.
class _Row {
  const _Row({
    required this.top,
    required this.height,
    required this.width,
    required this.color,
    required this.radius,
  });

  final double top;
  final double height;
  final double width;
  final Color color;
  final double radius;
}
