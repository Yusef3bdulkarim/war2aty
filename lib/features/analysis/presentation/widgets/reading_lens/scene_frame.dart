import 'dart:ui';

import 'lens_timeline.dart';
import 'paper_frame.dart';
import 'paper_painting.dart';

/// The whole scene at one moment: the paper, the lens, the light behind
/// them, and the finish (F22 #18, the C+ design).
///
/// Pure functions of the clock, like [PaperFrame], so the painter only draws
/// and every beat of the reading and the finish is testable without a
/// widget.
final class SceneFrame {
  const SceneFrame({
    required this.paper,
    required this.lens,
    this.lensBob = 0,
    this.lensOpacity = 1,
    this.glint,
    this.paperFloat = 0,
    this.spotlight = Offset.zero,
    this.settled = 0,
    this.check = 0,
    this.checkRing,
  });

  /// The lens reading, [seconds] after the page appeared.
  factory SceneFrame.reading(double seconds) {
    final lens = LensTimeline.lensAt(seconds);
    return SceneFrame(
      paper: PaperFrame.at(seconds),
      lens: lens,
      lensBob: LensTimeline.bobAt(seconds),
      glint: LensTimeline.glintAt(seconds),
      paperFloat: LensTimeline.floatAt(seconds),
      spotlight: LensTimeline.spotlightFor(lens),
    );
  }

  /// The finish, [seconds] after the page appeared, the result having arrived
  /// at [finishedAt] (F22 #10, #18): the lens fades as it keeps reading, the
  /// check springs in with a ring spreading from it, and the paper, its float
  /// and the light behind it come to rest in green.
  factory SceneFrame.finishing(double seconds, {required double finishedAt}) {
    final since = seconds - finishedAt;
    final settled = _eased(since, LensTimeline.finishSettle);
    final ring = since / _seconds(LensTimeline.finishRing);
    return SceneFrame(
      paper: PaperFrame.finished,
      lens: LensTimeline.lensAt(seconds),
      lensBob: LensTimeline.bobAt(finishedAt) * (1 - settled),
      lensOpacity: 1 - _eased(since, LensTimeline.lensFade),
      paperFloat: LensTimeline.floatAt(finishedAt) * (1 - settled),
      spotlight:
          LensTimeline.spotlightFor(LensTimeline.lensAt(finishedAt)) *
          (1 - settled),
      settled: settled,
      check: PaperPainting.easeOutBack(
        (since / _seconds(LensTimeline.checkPop)).clamp(0.0, 1.0),
      ),
      checkRing: ring < 1 ? ring : null,
    );
  }

  /// Under reduced motion, while waiting: the lens still, in the middle.
  static final SceneFrame resting = SceneFrame(
    paper: PaperFrame.resting,
    lens: LensTimeline.centre,
  );

  /// Under reduced motion, once the result has arrived: the check, still.
  static final SceneFrame restingFinished = SceneFrame(
    paper: PaperFrame.finished,
    lens: LensTimeline.centre,
    lensOpacity: 0,
    settled: 1,
    check: 1,
  );

  final PaperFrame paper;

  /// The lens centre, in paper units, and how far it has bobbed below it.
  final Offset lens;
  final double lensBob;
  final double lensOpacity;

  /// Where the glint is in its sweep across the glass (0 → 1), or null
  /// between sweeps.
  final double? glint;

  /// How far the paper (and everything on it) has floated, in paper units;
  /// negative is up.
  final double paperFloat;

  /// Where the light behind the paper is, from the paper's middle.
  final Offset spotlight;

  /// How far the finish has settled (0 → 1): the paper's green ring and the
  /// light turning green.
  final double settled;

  /// The finish check's size, 0 → 1 (it overshoots a little on the way).
  final double check;

  /// The ring spreading from the check (0 → 1), or null when there is none.
  final double? checkRing;

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;

  static double _eased(double seconds, Duration over) =>
      PaperPainting.easeOutCubic((seconds / _seconds(over)).clamp(0.0, 1.0));
}
