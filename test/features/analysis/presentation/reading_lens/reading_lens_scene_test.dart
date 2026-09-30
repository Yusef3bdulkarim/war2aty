import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/lens_timeline.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/reading_lens_painter.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/reading_lens_scene.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/scene_frame.dart';

import '../../../../support/pump_app.dart';

SceneFrame _frame(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(ReadingLensScene),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter! as ReadingLensPainter).scene.value;
}

void main() {
  late ValueNotifier<bool> finishing;
  late ValueNotifier<bool> shown;
  late int checks;
  late int finished;

  setUp(() {
    finishing = ValueNotifier(false);
    shown = ValueNotifier(true);
    checks = 0;
    finished = 0;
  });

  tearDown(() {
    finishing.dispose();
    shown.dispose();
  });

  Widget harness({bool reducedMotion = false, bool startFinishing = false}) {
    if (startFinishing) finishing.value = true;
    final scene = ValueListenableBuilder<bool>(
      valueListenable: shown,
      builder: (context, isShown, _) => !isShown
          ? const SizedBox.shrink()
          : ValueListenableBuilder<bool>(
              valueListenable: finishing,
              builder: (context, isFinishing, _) => Center(
                child: ReadingLensScene(
                  finishing: isFinishing,
                  onCheckShown: () => checks++,
                  onFinished: () => finished++,
                ),
              ),
            ),
    );
    if (!reducedMotion) return scene;
    return Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: scene,
      ),
    );
  }

  group('ReadingLensScene while waiting', () {
    testWidgets('the lens follows the timeline on the ticker\'s clock', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(_frame(tester).lens, LensTimeline.lensAt(2.4));

      // 7.5 s: the second pass, its first part already re-checked.
      await tester.pump(const Duration(milliseconds: 5100));
      expect(_frame(tester).lens, LensTimeline.lensAt(7.5));
      expect(_frame(tester).paper.checks.first, 1, reason: 'a later pass');
      expect(checks, 0);
      expect(finished, 0);
    });

    testWidgets('is sized to the paper and fits a narrow space', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Center(child: SizedBox(width: 200, child: ReadingLensScene())),
        settle: false,
      );
      final size = tester.getSize(find.byType(CustomPaint).last);
      expect(size.width, 200);
      expect(size.height, closeTo(200 * 340 / 260, 0.01));
    });
  });

  group('ReadingLensScene finishing', () {
    testWidgets('shows the check, then reports the finish, each once', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 3));

      finishing.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(checks, 0, reason: 'the check waits 120 ms');

      await tester.pump(const Duration(milliseconds: 40));
      expect(checks, 1);
      expect(finished, 0);

      await tester.pump(const Duration(milliseconds: 500));
      expect(finished, 0, reason: 'the beat is 650 ms');
      await tester.pump(const Duration(milliseconds: 20));
      expect(finished, 1);
      expect(_frame(tester).check, greaterThan(0.9));

      await tester.pump(const Duration(seconds: 2));
      expect(checks, 1);
      expect(finished, 1);
      expect(tester.hasRunningAnimations, isFalse, reason: 'ticker off');
    });

    testWidgets('finishes when it opens already finishing', (tester) async {
      await pumpApp(tester, harness(startFinishing: true), settle: false);
      await tester.pump(const Duration(milliseconds: 700));
      expect(checks, 1);
      expect(finished, 1);
    });

    testWidgets('removal stops everything and reports nothing', (tester) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 2));
      finishing.value = true;
      await tester.pump(const Duration(milliseconds: 50));

      shown.value = false;
      await tester.pump();
      expect(find.byType(ReadingLensScene), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(checks, 0);
      expect(finished, 0);
    });
  });

  group('ReadingLensScene under reduced motion', () {
    testWidgets('rests over the title and schedules no frames', (tester) async {
      await pumpApp(tester, harness(reducedMotion: true), settle: false);
      await tester.pump(const Duration(seconds: 5));
      expect(_frame(tester), same(SceneFrame.resting));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('shows the check at once and finishes after the hold', (
      tester,
    ) async {
      await pumpApp(tester, harness(reducedMotion: true), settle: false);
      await tester.pump(const Duration(seconds: 2));

      finishing.value = true;
      await tester.pump();
      expect(_frame(tester), same(SceneFrame.restingFinished));
      expect(checks, 1);
      expect(finished, 0);

      await tester.pump(const Duration(milliseconds: 490));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(finished, 1);
      expect(checks, 1);
    });

    testWidgets('removal during the hold reports nothing', (tester) async {
      await pumpApp(tester, harness(reducedMotion: true), settle: false);
      finishing.value = true;
      await tester.pump();
      shown.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 0);
    });
  });
}
