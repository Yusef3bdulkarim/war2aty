import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/presentation/widgets/analysis_progress_view.dart';

import '../../../support/pump_app.dart';

double _fill(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(
      find.descendant(
        of: find.byType(AnalysisProgressView),
        matching: find.byType(FractionallySizedBox),
      ),
    )
    .widthFactor!;

/// The fill as painted — the factor alone can animate while the box stays
/// invisible.
Size _fillSize(WidgetTester tester) => tester.getSize(
  find.descendant(
    of: find.byType(FractionallySizedBox),
    matching: find.byType(DecoratedBox),
  ),
);

void main() {
  late ValueNotifier<bool> finishing;
  late ValueNotifier<bool> shown;
  late int finished;

  setUp(() {
    finishing = ValueNotifier(false);
    shown = ValueNotifier(true);
    finished = 0;
  });

  tearDown(() {
    finishing.dispose();
    shown.dispose();
  });

  /// The view as the result screen drives it: `finishing` flips once the
  /// analysis answers, and the page can be removed at any time.
  Widget harness({bool reducedMotion = false}) {
    final view = ValueListenableBuilder<bool>(
      valueListenable: shown,
      builder: (context, isShown, _) => !isShown
          ? const SizedBox.shrink()
          : ValueListenableBuilder<bool>(
              valueListenable: finishing,
              builder: (context, isFinishing, _) => AnalysisProgressView(
                finishing: isFinishing,
                onFinished: () => finished++,
              ),
            ),
    );
    if (!reducedMotion) return view;
    return Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: view,
      ),
    );
  }

  group('AnalysisProgressView bar', () {
    testWidgets('paints the fill at the bar\'s full height', (tester) async {
      // Regression: the fill animated its width at zero height, so only the
      // pale track showed on the phone.
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 8));

      final size = _fillSize(tester);
      expect(size.height, 8);
      expect(size.width, closeTo(220 * _fill(tester), 0.5));
    });

    testWidgets('keeps moving towards 90% for the whole wait', (tester) async {
      await pumpApp(tester, harness(), settle: false);
      expect(_fill(tester), 0);

      await tester.pump(const Duration(seconds: 5));
      final at5s = _fill(tester);
      expect(at5s, inInclusiveRange(0.45, 0.58));

      await tester.pump(const Duration(seconds: 11));
      final at16s = _fill(tester);
      expect(at16s, inInclusiveRange(0.80, 0.88), reason: 'L1 took 16.6 s');

      // Still visibly moving at the server's 25 s deadline…
      await tester.pump(const Duration(seconds: 9));
      final at25s = _fill(tester);
      expect(at25s, greaterThan(at16s));
      expect(at25s, lessThan(0.9));

      // …and it never passes 90% while waiting, however long that is.
      await tester.pump(const Duration(minutes: 2));
      expect(_fill(tester), closeTo(0.9, 1e-9));
      expect(finished, 0);
    });

    testWidgets('runs to full from where it was, then reports it once', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 8));
      final atAnswer = _fill(tester);

      finishing.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_fill(tester), greaterThan(atAnswer));
      expect(_fill(tester), lessThan(1));
      expect(finished, 0, reason: 'not before the bar is full');

      await tester.pump(const Duration(milliseconds: 250));
      expect(_fill(tester), 1);
      expect(finished, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(finished, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('removing the page halts the bar and never reports finishing', (
      tester,
    ) async {
      // The error path: the failure page replaces this one mid-animation.
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 3));
      finishing.value = true;
      await tester.pump(const Duration(milliseconds: 100));

      shown.value = false;
      await tester.pump();

      expect(find.byType(AnalysisProgressView), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 0);
    });

    testWidgets('under reduced motion it stands still and finishes at once', (
      tester,
    ) async {
      await pumpApp(tester, harness(reducedMotion: true), settle: false);
      expect(_fill(tester), 0.9);
      expect(tester.hasRunningAnimations, isFalse);

      finishing.value = true;
      await tester.pump();
      expect(_fill(tester), 1);
      expect(finished, 1);
    });
  });
}
