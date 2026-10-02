import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/lens_timeline.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_frame.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/scene_frame.dart';

void main() {
  group('SceneFrame.reading', () {
    test('follows the timeline, with the bob, float, glint and light', () {
      for (final t in [0.7, 2.5, 4.4, 9.1]) {
        final frame = SceneFrame.reading(t);
        final lens = LensTimeline.lensAt(t);
        expect(frame.lens, lens);
        expect(frame.lensBob, LensTimeline.bobAt(t));
        expect(frame.paperFloat, LensTimeline.floatAt(t));
        expect(frame.glint, LensTimeline.glintAt(t));
        expect(frame.spotlight, LensTimeline.spotlightFor(lens));
        expect(frame.lensOpacity, 1);
      }
    });

    test('shows no finish', () {
      final frame = SceneFrame.reading(3);
      expect(frame.check, 0);
      expect(frame.checkRing, isNull);
      expect(frame.settled, 0);
    });
  });

  group('SceneFrame.finishing', () {
    const at = 3.0;
    SceneFrame since(double s) => SceneFrame.finishing(at + s, finishedAt: at);

    test('the lens keeps reading as it fades out over 400 ms', () {
      expect(since(0).lensOpacity, 1);
      expect(since(0.2).lens, LensTimeline.lensAt(at + 0.2));
      expect(since(0.2).lensOpacity, inExclusiveRange(0, 1));
      expect(since(0.4).lensOpacity, closeTo(0, 1e-9));
    });

    test('the check springs in at once, overshooting a little', () {
      expect(since(0).check, closeTo(0, 1e-9));
      final values = [for (var s = 0.0; s <= 0.42; s += 0.02) since(s).check];
      expect(values.reduce((a, b) => a > b ? a : b), greaterThan(1));
      expect(since(0.42).check, closeTo(1, 1e-9));
    });

    test('the ring spreads over 900 ms, then is gone', () {
      expect(since(0).checkRing, 0);
      expect(since(0.45).checkRing, closeTo(0.5, 1e-9));
      expect(since(0.95).checkRing, isNull);
    });

    test('the float, the bob and the light come to rest in green', () {
      final start = since(0);
      expect(start.paperFloat, LensTimeline.floatAt(at));
      expect(start.lensBob, LensTimeline.bobAt(at));
      final rest = since(0.5);
      expect(rest.paperFloat, closeTo(0, 1e-9));
      expect(rest.lensBob, closeTo(0, 1e-9));
      expect(rest.spotlight.distance, closeTo(0, 1e-9));
      expect(rest.settled, 1);
      expect(rest.paper, same(PaperFrame.finished));
      expect(rest.glint, isNull);
    });
  });

  group('SceneFrame resting frames', () {
    test(
      'reduced motion: the lens still in the middle, the check when done',
      () {
        expect(SceneFrame.resting.lens, LensTimeline.centre);
        expect(SceneFrame.resting.spotlight, Offset.zero);
        expect(SceneFrame.resting.check, 0);
        expect(SceneFrame.resting.glint, isNull);
        expect(SceneFrame.restingFinished.check, 1);
        expect(SceneFrame.restingFinished.lensOpacity, 0);
        expect(SceneFrame.restingFinished.settled, 1);
      },
    );
  });
}
