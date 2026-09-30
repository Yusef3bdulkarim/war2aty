import 'dart:math' as math;

import 'lens_timeline.dart';
import 'paper_layout.dart';

/// How far along each of the paper's reactions to the lens is at one moment.
///
/// A pure function of the clock ([PaperFrame.at]), so the painter keeps no
/// state of its own and every fade is exact on any frame. Amounts run 0 → 1.
final class PaperFrame {
  const PaperFrame({
    required this.wordLit,
    required this.wordRead,
    required this.titleLit,
    required this.titleOutline,
    required this.keyUnderline,
    required this.fieldActive,
    required this.fieldVisited,
    required this.checks,
  });

  /// The paper at [seconds] since the page appeared, the lens moving.
  factory PaperFrame.at(double seconds) {
    final pass = LensTimeline.passOf(seconds);
    final t = LensTimeline.timeInPass(seconds);
    final lens = LensTimeline.lensAt(seconds);
    final reread = pass > 0;

    return PaperFrame(
      wordLit: [
        for (final word in PaperLayout.words)
          _litBy(LensTimeline.distanceToRect(lens, word.rect)),
      ],
      wordRead: [for (final at in LensTimeline.wordReadAt) reread || t >= at],
      titleLit: _litBy(LensTimeline.distanceToRect(lens, PaperLayout.title)),
      titleOutline: reread
          ? 1
          : _progress(t, LensTimeline.titleReachedAt, _outlineDraw),
      keyUnderline: reread
          ? 1
          : _progress(t, LensTimeline.keyWordReachedAt, _underlineDraw),
      fieldActive: [
        for (final (start, end) in LensTimeline.fieldPauses)
          _pauseGlow(t, start, end),
      ],
      fieldVisited: [
        for (final (_, end) in LensTimeline.fieldPauses) reread || t >= end,
      ],
      checks: [
        for (final check in LensTimeline.reviewChecks)
          _checkAmount(pass, t, check.at),
      ],
    );
  }

  /// Under reduced motion: the lens rests over the title, and what it would
  /// have marked is already drawn (F22 #12).
  static final PaperFrame resting = PaperFrame(
    wordLit: List.filled(PaperLayout.words.length, 0),
    wordRead: List.filled(PaperLayout.words.length, false),
    titleLit: 1,
    titleOutline: 1,
    keyUnderline: 1,
    fieldActive: List.filled(PaperLayout.fields.length, 0),
    fieldVisited: List.filled(PaperLayout.fields.length, false),
    checks: List.filled(LensTimeline.reviewChecks.length, 0),
  );

  /// The paper once the result has arrived: every word read, nothing lit,
  /// the checks cleared; the title outline and the underline stay.
  static final PaperFrame finished = PaperFrame(
    wordLit: List.filled(PaperLayout.words.length, 0),
    wordRead: List.filled(PaperLayout.words.length, true),
    titleLit: 0,
    titleOutline: 1,
    keyUnderline: 1,
    fieldActive: List.filled(PaperLayout.fields.length, 0),
    fieldVisited: List.filled(PaperLayout.fields.length, true),
    checks: List.filled(LensTimeline.reviewChecks.length, 0),
  );

  /// Per word, in [PaperLayout.words] order: how teal it is under the lens.
  final List<double> wordLit;

  /// Per word: whether the lens has read it this pass (or any earlier one).
  final List<bool> wordRead;

  final double titleLit;
  final double titleOutline;
  final double keyUnderline;

  /// Per field, in [PaperLayout.fields] order: its glow while the lens
  /// pauses on it.
  final List<double> fieldActive;

  /// Per field: whether the lens has been there.
  final List<bool> fieldVisited;

  /// Per review check, in [LensTimeline.reviewChecks] order.
  final List<double> checks;

  static const double _outlineDraw = 0.35;
  static const double _underlineDraw = 0.42;
  static const double _fieldFade = 0.3;
  static const double _checkPop = 0.32;
  static const double _checkFade = 0.25;

  /// Fully lit this close to the lens centre, not at all from twice as far.
  static double _litBy(double distance) {
    const full = LensTimeline.litDistance * 2 / 3;
    const none = LensTimeline.litDistance * 4 / 3;
    final u = ((none - distance) / (none - full)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  static double _progress(double t, double from, double over) =>
      ((t - from) / over).clamp(0.0, 1.0);

  /// Rises over the pause, and fades out once the lens moves on.
  static double _pauseGlow(double t, double start, double end) => math.min(
    _progress(t, start, _fieldFade),
    ((end + _fieldFade - t) / _fieldFade).clamp(0.0, 1.0),
  );

  /// From the second pass on, each check pops in as the lens leaves its part.
  /// A pass starts by fading out the previous pass's checks.
  static double _checkAmount(int pass, double t, double at) {
    if (pass < 1) return 0;
    final popping = _progress(t, at, _checkPop);
    if (pass < 2 || t >= _checkFade) return popping;
    return math.max(popping, 1 - t / _checkFade);
  }
}
