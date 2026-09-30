import 'dart:math' as math;
import 'dart:ui';

import 'lens_timeline.dart';
import 'paper_frame.dart';
import 'paper_painting.dart';

/// The whole scene at one moment: the paper, the lens, and the finish.
///
/// Pure functions of the clock, like [PaperFrame], so the painter only draws
/// and every beat of the entrance, the reading and the finish is testable
/// without a widget.
final class SceneFrame {
  const SceneFrame({
    required this.paper,
    required this.lens,
    required this.handleDegrees,
    this.paperOpacity = 1,
    this.paperRise = 0,
    this.lensScale = 1,
    this.lensOpacity = 1,
    this.glint,
    this.finishRing = 0,
    this.check = 0,
    this.checkRing,
  });

  /// The lens reading, [seconds] after the page appeared.
  factory SceneFrame.reading(double seconds) {
    final paperIn = _eased(seconds, LensTimeline.paperEntrance);
    final lensIn = _eased(seconds, LensTimeline.lensEntrance);
    return SceneFrame(
      paper: PaperFrame.at(seconds),
      lens: LensTimeline.lensAt(seconds),
      handleDegrees: LensTimeline.handleSwingAt(seconds),
      paperOpacity: paperIn,
      paperRise: _entranceRise * (1 - paperIn),
      lensScale: 0.6 + 0.4 * lensIn,
      lensOpacity: lensIn,
      glint: _glintAt(seconds),
    );
  }

  /// The finish, [seconds] after the page appeared, the result having arrived
  /// at [finishedAt] (F22 #10): the lens glides from where it was to the
  /// centre and fades; the check springs in; a ring spreads from it.
  factory SceneFrame.finishing(double seconds, {required double finishedAt}) {
    final since = seconds - finishedAt;
    final glide = _eased(since, LensTimeline.finishGlide);
    final from = LensTimeline.lensAt(finishedAt);
    final checkSince = since - _seconds(LensTimeline.checkDelay);
    final ringSince = since - _ringDelay;
    final ring = ringSince / _seconds(LensTimeline.finishRing);
    return SceneFrame(
      paper: PaperFrame.finished,
      lens: Offset.lerp(from, LensTimeline.centre, glide)!,
      handleDegrees: LensTimeline.handleSwingAt(finishedAt) * (1 - glide),
      lensScale: 1 - 0.5 * glide,
      lensOpacity: 1 - glide,
      finishRing: (since / _finishRingDraw).clamp(0.0, 1.0),
      check: PaperPainting.easeOutBack(
        (checkSince / _seconds(LensTimeline.checkPop)).clamp(0.0, 1.0),
      ),
      checkRing: ring >= 0 && ring < 1 ? ring : null,
    );
  }

  /// Under reduced motion, while waiting: the lens rests over the title.
  static final SceneFrame resting = SceneFrame(
    paper: PaperFrame.resting,
    lens: LensTimeline.restingPoint,
    handleDegrees: 0,
  );

  /// Under reduced motion, once the result has arrived: the check, still.
  static final SceneFrame restingFinished = SceneFrame(
    paper: PaperFrame.finished,
    lens: LensTimeline.restingPoint,
    handleDegrees: 0,
    lensOpacity: 0,
    finishRing: 1,
    check: 1,
  );

  final PaperFrame paper;

  /// The lens centre, in paper units.
  final Offset lens;
  final double handleDegrees;

  final double paperOpacity;

  /// How far below its place the paper still is, in paper units.
  final double paperRise;

  final double lensScale;
  final double lensOpacity;

  /// Where the glint is in its sweep across the glass (0 → 1), or null
  /// between sweeps.
  final double? glint;

  /// The green ring around the paper (0 → 1).
  final double finishRing;

  /// The finish check's size, 0 → 1 (it overshoots a little on the way).
  final double check;

  /// The ring spreading from the check (0 → 1), or null when there is none.
  final double? checkRing;

  static const double _entranceRise = 12;
  static const double _finishRingDraw = 0.5;
  static const double _ringDelay = 0.25;

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;

  static double _eased(double seconds, Duration over) =>
      PaperPainting.easeOutCubic((seconds / _seconds(over)).clamp(0.0, 1.0));

  static double? _glintAt(double seconds) {
    final since = seconds - LensTimeline.glintDelay;
    if (since < 0) return null;
    final phase = (since % LensTimeline.glintPeriod) / LensTimeline.glintPeriod;
    if (phase >= LensTimeline.glintSweep) return null;
    final u = phase / LensTimeline.glintSweep;
    // Ease in and out across the glass.
    return u < 0.5 ? 2 * u * u : 1 - math.pow(-2 * u + 2, 2) / 2;
  }
}
