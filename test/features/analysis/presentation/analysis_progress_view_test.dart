import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/presentation/widgets/analysis_progress_view.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/reading_lens_scene.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/wait_caption.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

/// What the page has sent to the screen reader since the last call — taken
/// from the platform channel itself, so it is what TalkBack and VoiceOver
/// would have been asked to say.
List<String> _spoken(WidgetTester tester) => [
  for (final announcement in tester.takeAnnouncements()) announcement.message,
];

void main() {
  late ValueNotifier<bool> finishing;
  late ValueNotifier<bool> shown;
  late int finished;
  late List<Object?> haptics;

  setUp(() {
    finishing = ValueNotifier(false);
    shown = ValueNotifier(true);
    finished = 0;
    haptics = [];
  });

  tearDown(() {
    finishing.dispose();
    shown.dispose();
  });

  /// Records every haptic the page asks the platform for.
  void recordHaptics(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

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

  group('AnalysisProgressView while waiting', () {
    testWidgets('shows the magnifier and what it is looking for', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      expect(find.byType(ReadingLensScene), findsOneWidget);
      expect(find.byType(WaitCaption), findsOneWidget);
      expect(
        find.textContaining(_strings.analysisWaitStepType, findRichText: true),
        findsOneWidget,
      );
      // Nothing to tap and nothing to cancel (F22).
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('announces the wait once, as the page appears', (tester) async {
      // Regression: a live region speaks only when its label changes, so the
      // first announcement never reached TalkBack.
      await pumpApp(tester, harness(), settle: false);
      await tester.pump();
      expect(_spoken(tester), [_strings.analysisRunningStatus]);

      // The captions follow a clock: they are never read out.
      await tester.pump(const Duration(seconds: 7));
      expect(_spoken(tester), isEmpty);
    });

    testWidgets('waits for the page to finish sliding in before speaking', (
      tester,
    ) async {
      // The screen reader announces the new screen as it arrives; speaking
      // over it is what made VoiceOver drop the first announcement.
      await pumpApp(tester, const SizedBox.shrink());
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(MaterialPageRoute<void>(builder: (_) => harness())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_spoken(tester), isEmpty, reason: 'still sliding in');

      await tester.pump(const Duration(seconds: 1));
      expect(_spoken(tester), [_strings.analysisRunningStatus]);
    });

    testWidgets('announces a long wait once, at 15 s', (tester) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump();
      _spoken(tester);

      await tester.pump(const Duration(milliseconds: 14900));
      expect(_spoken(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_spoken(tester), [_strings.analysisWaitLongAnnouncement]);

      await tester.pump(const Duration(seconds: 20));
      expect(_spoken(tester), isEmpty);
    });

    testWidgets('a result right at 15 s is announced as ready, not long', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      await tester.pump();
      _spoken(tester);
      await tester.pump(const Duration(milliseconds: 14990));

      finishing.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_spoken(tester), [_strings.analysisWaitReadyAnnouncement]);
    });

    testWidgets('the page keeps a label for swiping onto it', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, harness(), settle: false);
      expect(
        find.bySemanticsLabel(_strings.analysisRunningStatus),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 16));
      expect(
        find.bySemanticsLabel(_strings.analysisWaitLongAnnouncement),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('never vibrates while waiting', (tester) async {
      recordHaptics(tester);
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 25));
      expect(haptics, isEmpty);
      expect(finished, 0);
    });
  });

  group('AnalysisProgressView finishing', () {
    testWidgets('one light haptic as the check appears, then the finish', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      recordHaptics(tester);
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 5));

      finishing.value = true;
      await tester.pump();
      expect(haptics, isEmpty);

      // The check springs in on the next frame, the haptic and the
      // announcement with it.
      _spoken(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(
        find.bySemanticsLabel(_strings.analysisWaitReadyAnnouncement),
        findsOneWidget,
      );
      expect(_spoken(tester), [_strings.analysisWaitReadyAnnouncement]);
      expect(finished, 0);

      await tester.pump(const Duration(milliseconds: 600));
      expect(finished, 0);
      await tester.pump(const Duration(milliseconds: 40));
      expect(finished, 1);
      expect(find.text(_strings.analysisWaitReady), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(haptics, hasLength(1));
      expect(finished, 1);
      semantics.dispose();
    });

    testWidgets('removal mid-finish stops it: no finish, no second haptic', (
      tester,
    ) async {
      // The error path: the failure page replaces this one mid-finish.
      recordHaptics(tester);
      await pumpApp(tester, harness(), settle: false);
      await tester.pump(const Duration(seconds: 3));
      finishing.value = true;
      await tester.pump(const Duration(milliseconds: 50));

      shown.value = false;
      await tester.pump();
      expect(find.byType(AnalysisProgressView), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pump(const Duration(seconds: 2));
      // The haptic came with the check, before the page went; nothing after.
      expect(haptics, hasLength(1));
      expect(finished, 0);
    });
  });

  group('AnalysisProgressView under reduced motion', () {
    testWidgets('runs no animation, yet the captions still change', (
      tester,
    ) async {
      await pumpApp(tester, harness(reducedMotion: true), settle: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(
        find.textContaining(
          _strings.analysisWaitStepActions,
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('finishes with the haptic after a still hold', (tester) async {
      recordHaptics(tester);
      await pumpApp(tester, harness(reducedMotion: true), settle: false);
      await tester.pump(const Duration(seconds: 2));

      finishing.value = true;
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(finished, 0);

      await tester.pump(const Duration(milliseconds: 510));
      expect(finished, 1);
      expect(haptics, hasLength(1));
    });
  });

  group('AnalysisProgressView layout', () {
    testWidgets('fits a small phone under the largest text, both languages', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in [
        AppLocalizations.arabic,
        AppLocalizations.english,
      ]) {
        await pumpApp(
          tester,
          harness(),
          locale: locale,
          textScaler: const TextScaler.linear(2),
          settle: false,
        );
        // Through every caption, the longest last.
        await tester.pump(const Duration(seconds: 16));
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    });

    testWidgets('reads right to left in Arabic, left to right in English', (
      tester,
    ) async {
      await pumpApp(tester, harness(), settle: false);
      expect(
        Directionality.of(tester.element(find.byType(WaitCaption))),
        TextDirection.rtl,
      );
      await pumpApp(
        tester,
        harness(),
        locale: AppLocalizations.english,
        settle: false,
      );
      expect(
        Directionality.of(tester.element(find.byType(WaitCaption))),
        TextDirection.ltr,
      );
      expect(
        find.textContaining(
          const EnStrings().analysisWaitStepType,
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });
}
