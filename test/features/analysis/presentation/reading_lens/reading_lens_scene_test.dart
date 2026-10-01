import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/lens_timeline.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_layout.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/reading_lens_painter.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/reading_lens_scene.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/scene_frame.dart';

import '../../../../support/pump_app.dart';

ReadingLensPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(ReadingLensScene),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as ReadingLensPainter;
}

/// The physical pixels per paper unit the scene draws the stack at.
double _scale(WidgetTester tester, ReadingLensPainter painter) {
  final width = tester.getSize(find.byType(ReadingLensScene)).width;
  return width / PaperLayout.size.width * painter.devicePixelRatio;
}

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

      // 10.5 s: the second pass, its first line already re-checked.
      await tester.pump(const Duration(milliseconds: 8100));
      expect(_frame(tester).lens, LensTimeline.lensAt(10.5));
      expect(
        _frame(tester).paper.checks.first.opacity,
        1,
        reason: 'a later pass',
      );
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
      expect(size.height, closeTo(200 * 360 / 260, 0.01));
    });
  });

  group('ReadingLensScene stack', () {
    testWidgets('renders the sheet stack once, not on every frame', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(milliseconds: 16));
      final painter = _painter(tester);
      final image = painter.stack.imageFor(
        painter.colors,
        _scale(tester, painter),
      );

      // Five seconds of reading, the paper floating all the while.
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        _painter(
          tester,
        ).stack.imageFor(painter.colors, _scale(tester, painter)),
        same(image),
      );
      expect(image.debugDisposed, isFalse);
    });

    testWidgets('frees the stack image when the scene goes', (tester) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(milliseconds: 16));
      final painter = _painter(tester);
      final image = painter.stack.imageFor(
        painter.colors,
        _scale(tester, painter),
      );

      shown.value = false;
      await tester.pump();
      expect(image.debugDisposed, isTrue);
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
      // The check springs in on the next frame (F22 #18).
      await tester.pump(const Duration(milliseconds: 16));
      expect(checks, 1);
      expect(finished, 0);

      await tester.pump(const Duration(milliseconds: 600));
      expect(finished, 0, reason: 'the beat is 650 ms');
      await tester.pump(const Duration(milliseconds: 40));
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

    testWidgets('removal mid-finish stops it, and never reports the finish', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 2));
      finishing.value = true;
      await tester.pump(const Duration(milliseconds: 50));

      shown.value = false;
      await tester.pump();
      expect(find.byType(ReadingLensScene), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pump(const Duration(seconds: 2));
      // The check had already sprung in; the finish never comes.
      expect(checks, 1);
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
