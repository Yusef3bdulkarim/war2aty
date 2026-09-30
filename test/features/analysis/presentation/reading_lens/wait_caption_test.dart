import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/wait_caption.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();

Finder _showing(String text) => find.textContaining(text, findRichText: true);

void main() {
  late ValueNotifier<bool> finished;
  late int longWaits;

  setUp(() {
    finished = ValueNotifier(false);
    longWaits = 0;
  });

  tearDown(() => finished.dispose());

  Widget harness({bool reducedMotion = false}) {
    final caption = ValueListenableBuilder<bool>(
      valueListenable: finished,
      builder: (context, isFinished, _) => Center(
        child: WaitCaption(finished: isFinished, onLongWait: () => longWaits++),
      ),
    );
    if (!reducedMotion) return caption;
    return Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: caption,
      ),
    );
  }

  /// Advances the clock to [seconds] since the caption appeared, then lets
  /// the crossfade finish.
  Future<void> at(WidgetTester tester, double seconds, double now) async {
    await tester.pump(Duration(milliseconds: ((seconds - now) * 1000).round()));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('each caption at its moment, the long hint from 10 s', (
    tester,
  ) async {
    await pumpApp(tester, harness(), settle: false);
    expect(_showing(_strings.analysisWaitStepType), findsOneWidget);
    expect(find.text(_strings.analysisWaitHint), findsOneWidget);

    final steps = [
      (1.6, _strings.analysisWaitStepActions),
      (3.9, _strings.analysisWaitStepDates),
      (6.0, _strings.analysisWaitStillSeconds),
      (10.0, _strings.analysisWaitReviewing),
      (15.0, _strings.analysisWaitTakingLonger),
    ];
    var now = 0.0;
    for (final (seconds, caption) in steps) {
      // Just before: still the previous caption.
      await tester.pump(
        Duration(milliseconds: ((seconds - now) * 1000).round() - 20),
      );
      expect(_showing(caption), findsNothing, reason: 'before $seconds s');
      await at(tester, seconds, seconds - 0.02);
      now = seconds + 0.5;
      expect(_showing(caption), findsOneWidget, reason: 'at $seconds s');
      expect(
        find.text(_strings.analysisWaitHintLong),
        seconds >= 10 ? findsOneWidget : findsNothing,
      );
    }
    expect(longWaits, 1);

    await tester.pump(const Duration(seconds: 30));
    expect(_showing(_strings.analysisWaitTakingLonger), findsOneWidget);
    expect(longWaits, 1);
  });

  testWidgets('says it is ready once finished, and stops the clock', (
    tester,
  ) async {
    await pumpApp(tester, harness(), settle: false);
    await tester.pump(const Duration(seconds: 2));

    finished.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(_strings.analysisWaitReady), findsOneWidget);
    expect(find.text(_strings.analysisWaitHintReady), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text(_strings.analysisWaitReady), findsOneWidget);
    expect(longWaits, 0);
  });

  testWidgets('the dots pulse, and stand still under reduced motion', (
    tester,
  ) async {
    await pumpApp(tester, harness(), settle: false);
    expect(tester.hasRunningAnimations, isTrue);

    await pumpApp(tester, harness(reducedMotion: true), settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('...'), findsOneWidget);

    await at(tester, 1.6, 0.5);
    expect(_showing(_strings.analysisWaitStepActions), findsOneWidget);
  });

  testWidgets('is not read out by assistive technology', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, harness(), settle: false);
    expect(
      find.bySemanticsLabel(RegExp(_strings.analysisWaitStepType)),
      findsNothing,
    );
    expect(find.bySemanticsLabel(_strings.analysisWaitHint), findsNothing);
    semantics.dispose();
  });

  testWidgets('removal cancels the clock', (tester) async {
    await pumpApp(tester, harness(), settle: false);
    await pumpApp(tester, const SizedBox.shrink(), settle: false);
    await tester.pump(const Duration(seconds: 20));
    expect(longWaits, 0);
  });
}
