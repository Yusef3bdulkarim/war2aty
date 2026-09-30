import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/lens_timeline.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_frame.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/scene_frame.dart';

void main() {
  group('SceneFrame.reading', () {
    test('the paper rises in and the lens grows in', () {
      final start = SceneFrame.reading(0);
      expect(start.paperOpacity, 0);
      expect(start.paperRise, 12);
      expect(start.lensOpacity, 0);
      expect(start.lensScale, closeTo(0.6, 1e-9));

      final entered = SceneFrame.reading(0.5);
      expect(entered.paperOpacity, 1);
      expect(entered.paperRise, 0);
      expect(entered.lensOpacity, 1);
      expect(entered.lensScale, 1);
    });

    test('follows the timeline', () {
      for (final t in [0.7, 2.5, 4.4, 9.1]) {
        final frame = SceneFrame.reading(t);
        expect(frame.lens, LensTimeline.lensAt(t));
        expect(frame.handleDegrees, LensTimeline.handleSwingAt(t));
      }
    });

    test('crosses the glass with a glint once per period, after a delay', () {
      expect(SceneFrame.reading(0.5).glint, isNull);
      expect(SceneFrame.reading(0.6).glint, 0);
      expect(SceneFrame.reading(0.6 + 0.48).glint, closeTo(0.5, 1e-9));
      expect(SceneFrame.reading(0.6 + 1.5).glint, isNull);
      expect(SceneFrame.reading(0.6 + 3.2 + 0.48).glint, closeTo(0.5, 1e-9));
    });

    test('shows no finish', () {
      final frame = SceneFrame.reading(3);
      expect(frame.check, 0);
      expect(frame.checkRing, isNull);
      expect(frame.finishRing, 0);
    });
  });

  group('SceneFrame.finishing', () {
    const at = 3.0;

    test('the lens glides from where it was to the centre and fades', () {
      final start = SceneFrame.finishing(at, finishedAt: at);
      expect(start.lens, LensTimeline.lensAt(at));
      expect(start.lensOpacity, 1);

      final end = SceneFrame.finishing(at + 0.35, finishedAt: at);
      expect(end.lens.dx, closeTo(LensTimeline.centre.dx, 1e-9));
      expect(end.lens.dy, closeTo(LensTimeline.centre.dy, 1e-9));
      expect(end.lensOpacity, closeTo(0, 1e-9));
      expect(end.lensScale, closeTo(0.5, 1e-9));
    });

    test('the check springs in after its delay, overshooting a little', () {
      expect(
        SceneFrame.finishing(at + 0.1, finishedAt: at).check,
        closeTo(0, 1e-9),
      );
      final values = [
        for (var s = 0.12; s <= 0.6; s += 0.02)
          SceneFrame.finishing(at + s, finishedAt: at).check,
      ];
      expect(values.reduce((a, b) => a > b ? a : b), greaterThan(1));
      expect(
        SceneFrame.finishing(at + 0.6, finishedAt: at).check,
        closeTo(1, 1e-9),
      );
    });

    test('the ring spreads between 0.25 and 1.15 s, then is gone', () {
      expect(SceneFrame.finishing(at + 0.2, finishedAt: at).checkRing, isNull);
      expect(
        SceneFrame.finishing(at + 0.7, finishedAt: at).checkRing,
        closeTo(0.5, 1e-9),
      );
      expect(SceneFrame.finishing(at + 1.2, finishedAt: at).checkRing, isNull);
    });

    test('the paper shows everything read and rings in green', () {
      final frame = SceneFrame.finishing(at + 0.6, finishedAt: at);
      expect(frame.paper, same(PaperFrame.finished));
      expect(frame.finishRing, 1);
    });
  });

  group('SceneFrame resting frames', () {
    test('reduced motion: the lens over the title, the check when done', () {
      expect(SceneFrame.resting.lens, LensTimeline.restingPoint);
      expect(SceneFrame.resting.check, 0);
      expect(SceneFrame.resting.glint, isNull);
      expect(SceneFrame.restingFinished.check, 1);
      expect(SceneFrame.restingFinished.lensOpacity, 0);
    });
  });
}
