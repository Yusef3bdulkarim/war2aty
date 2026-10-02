import 'dart:math' as math;
import 'dart:ui';

import 'paper_layout.dart';

/// A place on the lens's path, and when the lens reaches it.
final class _Waypoint {
  const _Waypoint(this.at, this.x, this.y);

  /// Seconds into the pass.
  final double at;
  final double x;
  final double y;
}

/// The magnifier's choreography: where the lens is at any moment, when each
/// word is read, and when the caption changes (F22 #18, the C+ design).
///
/// Everything is a pure function of the seconds since the page appeared, so
/// the scene, the captions and the tests all read the same clock. Times are
/// plain seconds (`double`) because the lens position is sampled every frame.
abstract final class LensTimeline {
  /// One reading of the whole paper, after which the lens starts again at the
  /// top.
  static const double pass = 8;

  /// The lens's path for one pass, at a steady speed between points; two
  /// points in the same place are a pause.
  static const List<_Waypoint> _path = [
    // The first body line.
    _Waypoint(0, 236, 96),
    _Waypoint(1.2, 24, 96),
    // The second, with a pause on its key word.
    _Waypoint(1.52, 236, 138),
    _Waypoint(1.84, 170, 138),
    _Waypoint(2.24, 170, 138),
    _Waypoint(2.88, 24, 138),
    // The third and the fourth.
    _Waypoint(3.2, 236, 180),
    _Waypoint(4.4, 24, 180),
    _Waypoint(4.72, 236, 222),
    _Waypoint(5.92, 24, 222),
    // The boxed field, with a pause on its value.
    _Waypoint(6.24, 236, 270),
    _Waypoint(6.88, 66, 270),
    _Waypoint(7.36, 66, 270),
    _Waypoint(7.6, 24, 270),
    // Back to the start.
    _Waypoint(pass, 236, 96),
  ];

  /// The middle of the paper: where the lens rests under reduced motion, and
  /// where the finish check appears.
  static const Offset centre = Offset(130, 180);

  /// When, in a pass, the lens finishes each line — the moment that line's
  /// review check pops in (F22 #8), in [PaperLayout.lineCentres] order.
  static const List<double> lineEnds = [1.2, 2.88, 4.4, 5.92, 7.6];

  /// Where each caption starts, in seconds since the page appeared (F22 #7).
  static const List<double> stepStarts = [0, 1.9, 3.8, 6, 10, 15];

  /// From here the subline says there is nothing to do.
  static const double longSublineAt = 10;

  /// From here the wait is announced as longer than usual (F22 #13).
  static const double longWaitAt = 15;

  /// The finish (F22 #10, #18): the lens fades as it keeps reading, the
  /// check springs in at once, a ring spreads from it, and the whole beat
  /// before the result is shown.
  static const Duration lensFade = Duration(milliseconds: 400);
  static const Duration checkPop = Duration(milliseconds: 420);
  static const Duration finishRing = Duration(milliseconds: 900);
  static const Duration finishSettle = Duration(milliseconds: 500);
  static const Duration finishBeat = Duration(milliseconds: 650);

  /// Under reduced motion, the check is held this long before the result.
  static const Duration reducedMotionHold = Duration(milliseconds: 500);

  /// The glint crosses the glass once per period, taking [glintSweep] of it.
  static const double glintPeriod = 2.8;
  static const double glintSweep = 0.35;

  /// The lens bobs [bobHeight] up and down, one way per [bobHalfPeriod], as
  /// if held by a hand.
  static const double bobHalfPeriod = 1.3;
  static const double bobHeight = 2;

  /// The paper floats [floatHeight] up and back once per [floatPeriod].
  static const double floatPeriod = 5;
  static const double floatHeight = 5;

  /// Which pass [seconds] falls in, from 0.
  static int passOf(double seconds) => (seconds / pass).floor();

  /// Seconds into the current pass.
  static double timeInPass(double seconds) => seconds - passOf(seconds) * pass;

  /// The lens centre at [seconds] since the page appeared, in paper units.
  static Offset lensAt(double seconds) {
    final t = timeInPass(seconds);
    for (var i = 1; i < _path.length; i++) {
      final from = _path[i - 1];
      final to = _path[i];
      if (t <= to.at) {
        final span = to.at - from.at;
        final k = span == 0 ? 1.0 : (t - from.at) / span;
        return Offset(
          from.x + (to.x - from.x) * k,
          from.y + (to.y - from.y) * k,
        );
      }
    }
    return Offset(_path.first.x, _path.first.y);
  }

  /// How far the light behind the paper has followed the lens, in paper
  /// units: a softer echo of its movement, about the paper's middle.
  static Offset spotlightFor(Offset lens) => Offset(
    (lens.dx - centre.dx) * 100 / 212,
    (lens.dy - centre.dy) * 20 / 42,
  );

  /// The lens's bob at [seconds]: from 2 above to 2 below and back.
  static double bobAt(double seconds) =>
      -bobHeight +
      2 * bobHeight * _easeInOut(_triangle(seconds, bobHalfPeriod));

  /// The paper's float at [seconds]: up to 5 and back down, per period.
  static double floatAt(double seconds) =>
      -floatHeight * _easeInOut(_triangle(seconds, floatPeriod / 2));

  /// Where the glint is in its sweep across the glass (0 → 1), or null
  /// between sweeps.
  static double? glintAt(double seconds) {
    final phase = (seconds % glintPeriod) / glintPeriod;
    if (phase >= glintSweep) return null;
    return _easeInOut(phase / glintSweep);
  }

  /// Which caption shows at [seconds]: an index into [stepStarts].
  static int stepAt(double seconds) {
    var step = 0;
    for (var i = 1; i < stepStarts.length; i++) {
      if (seconds >= stepStarts[i]) step = i;
    }
    return step;
  }

  /// When, in a pass, the lens centre crosses the middle of each of
  /// [PaperLayout.words] — the moment that word lights up. Same order.
  static final List<double> wordReadAt = [
    for (final word in PaperLayout.words) _crossing(word.rect.center),
  ];

  /// The first moment in a pass the lens centre is on [point], found along
  /// the path's segments.
  static double _crossing(Offset point) {
    for (var i = 1; i < _path.length; i++) {
      final from = _path[i - 1];
      final to = _path[i];
      if (from.y != point.dy || to.y != point.dy) continue;
      final lo = math.min(from.x, to.x);
      final hi = math.max(from.x, to.x);
      if (point.dx < lo || point.dx > hi) continue;
      if (from.x == to.x) return from.at;
      return from.at +
          (from.x - point.dx) / (from.x - to.x) * (to.at - from.at);
    }
    throw StateError('The lens never crosses $point');
  }

  /// 0 → 1 → 0, one way per [half] seconds.
  static double _triangle(double seconds, double half) {
    final u = (seconds / half) % 2;
    return u <= 1 ? u : 2 - u;
  }

  /// CSS's `ease-in-out`, closely enough for motion this small.
  static double _easeInOut(double u) =>
      u < 0.5 ? 4 * u * u * u : 1 - math.pow(-2 * u + 2, 3) / 2;
}
