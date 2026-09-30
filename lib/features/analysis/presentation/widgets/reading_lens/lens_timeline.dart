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

/// A small green check that marks a part of the paper as re-checked.
final class ReviewCheck {
  const ReviewCheck(this.topLeft, this.at);

  /// In paper units.
  final Offset topLeft;

  /// Seconds into a pass at which the lens leaves that part.
  final double at;
}

/// The magnifier's choreography: where the lens is at any moment, and when
/// the caption changes (F22 #6–#10).
///
/// Everything is a pure function of the seconds since the page appeared, so
/// the scene, the captions and the tests all read the same clock. Times are
/// plain seconds (`double`) because the lens position is sampled every frame.
abstract final class LensTimeline {
  /// One reading of the whole paper, after which the lens starts again at the
  /// top. Chosen so a normal 5–6 s analysis sees the page read exactly once.
  static const double pass = 5.75;

  /// The lens's path for one pass. It eases between consecutive points; two
  /// points in the same place are a pause.
  static const List<_Waypoint> _path = [
    // The header: onto the title, and a pause there.
    _Waypoint(0, 224, 38),
    _Waypoint(0.45, 152, 38),
    _Waypoint(0.95, 152, 38),
    // The first body line.
    _Waypoint(1.25, 228, 104),
    _Waypoint(1.85, 36, 104),
    // The second, with a pause on its key word.
    _Waypoint(2.1, 228, 140),
    _Waypoint(2.4, 170, 140),
    _Waypoint(2.7, 170, 140),
    _Waypoint(3.05, 36, 140),
    // The third.
    _Waypoint(3.3, 228, 176),
    _Waypoint(3.9, 36, 176),
    // Each field, with a pause.
    _Waypoint(4.2, 188, 246),
    _Waypoint(4.65, 188, 246),
    _Waypoint(4.95, 72, 246),
    _Waypoint(5.25, 72, 246),
    // Back to the start.
    _Waypoint(pass, 224, 38),
  ];

  /// Where the lens rests under reduced motion: over the title.
  static const Offset restingPoint = Offset(152, 38);

  /// Where the lens goes to finish, and where the check appears.
  static const Offset centre = Offset(130, 170);

  /// When the lens first reaches the title; its outline is drawn from then on.
  static const double titleReachedAt = 0.45;

  /// When the lens reaches the key word; its underline is drawn from then on.
  static const double keyWordReachedAt = 2.4;

  /// The two field pauses, in [PaperLayout.fields] order: `(start, end)`.
  static const List<(double, double)> fieldPauses = [(4.2, 4.65), (4.95, 5.25)];

  /// The review checks, drawn from the second pass on (F22 #8).
  static const List<ReviewCheck> reviewChecks = [
    ReviewCheck(Offset(74, 26), 0.95),
    ReviewCheck(Offset(6, 96), 1.85),
    ReviewCheck(Offset(6, 132), 3.05),
    ReviewCheck(Offset(6, 168), 3.9),
    ReviewCheck(Offset(228, 214), 4.65),
    ReviewCheck(Offset(112, 214), 5.25),
  ];

  /// A word is lit while it is this close to the lens centre, in paper units.
  static const double litDistance = 12;

  /// Where each caption starts, in seconds since the page appeared (F22 #7).
  /// The first three follow the lens (header, body, fields); the rest are
  /// the long-wait lines.
  static const List<double> stepStarts = [0, 1.6, 3.9, 6, 10, 15];

  /// From here the subline says there is nothing to do.
  static const double longSublineAt = 10;

  /// From here the wait is announced as longer than usual (F22 #13).
  static const double longWaitAt = 15;

  /// The entrance (F22 #9).
  static const Duration paperEntrance = Duration(milliseconds: 400);
  static const Duration lensEntrance = Duration(milliseconds: 350);

  /// The finish (F22 #10): the lens's glide to [centre], the check's delay
  /// and spring, the ring, and the whole beat before the result is shown.
  static const Duration finishGlide = Duration(milliseconds: 350);
  static const Duration checkDelay = Duration(milliseconds: 120);
  static const Duration checkPop = Duration(milliseconds: 440);
  static const Duration finishRing = Duration(milliseconds: 900);
  static const Duration finishBeat = Duration(milliseconds: 650);

  /// Under reduced motion, the check is held this long before the result.
  static const Duration reducedMotionHold = Duration(milliseconds: 500);

  /// The glint crosses the glass once per period, taking [glintSweep] of it.
  static const double glintPeriod = 3.2;
  static const double glintDelay = 0.6;
  static const double glintSweep = 0.3;

  /// The handle's swing, in degrees, per paper unit per second of sideways
  /// speed, and its limit.
  static const double handleSwingPerSpeed = 1 / 45;
  static const double handleSwingLimit = 10;

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
        final k = _easeInOutCubic(span == 0 ? 1 : (t - from.at) / span);
        return Offset(
          from.x + (to.x - from.x) * k,
          from.y + (to.y - from.y) * k,
        );
      }
    }
    return Offset(_path.first.x, _path.first.y);
  }

  /// The handle's swing at [seconds], in degrees: it trails the lens's
  /// sideways movement, as if held by a hand.
  static double handleSwingAt(double seconds) {
    const step = 0.03;
    final speed = (lensAt(seconds + step).dx - lensAt(seconds).dx) / step;
    return (speed * handleSwingPerSpeed).clamp(
      -handleSwingLimit,
      handleSwingLimit,
    );
  }

  /// Which caption shows at [seconds]: an index into [stepStarts].
  static int stepAt(double seconds) {
    var step = 0;
    for (var i = 1; i < stepStarts.length; i++) {
      if (seconds >= stepStarts[i]) step = i;
    }
    return step;
  }

  /// When, in a pass, the lens comes closest to each of [PaperLayout.words]
  /// — the moment that word turns «read». Same order as the words.
  static final List<double> wordReadAt = [
    for (final word in PaperLayout.words) _closestApproach(word.rect),
  ];

  /// The first time in a pass the lens comes nearest [rect], sampled every
  /// 10 ms.
  static double _closestApproach(Rect rect) {
    var best = double.infinity;
    var at = pass;
    for (var ms = 0; ms <= pass * 1000; ms += 10) {
      final t = ms / 1000;
      final d = distanceToRect(lensAt(t), rect);
      if (d < best - 0.01) {
        best = d;
        at = t;
      }
    }
    return at;
  }

  /// The distance from [point] to the nearest edge of [rect]; 0 inside it.
  static double distanceToRect(Offset point, Rect rect) {
    final dx = math.max(
      math.max(rect.left - point.dx, 0.0),
      point.dx - rect.right,
    );
    final dy = math.max(
      math.max(rect.top - point.dy, 0.0),
      point.dy - rect.bottom,
    );
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _easeInOutCubic(double u) =>
      u < 0.5 ? 4 * u * u * u : 1 - math.pow(-2 * u + 2, 3) / 2;
}
