import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/bootstrap/domain/entities/bootstrap_stage.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_state.dart';
import 'package:war2aty/features/bootstrap/presentation/screens/splash_screen.dart';
import 'package:war2aty/features/bootstrap/presentation/splash_timing.dart';
import 'package:war2aty/features/bootstrap/presentation/widgets/splash_hand_off.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  final mark = find.image(const AssetImage(kBrandMarkAsset));

  /// The mark's fade, and the scale inside it. Both are plain widgets rebuilt
  /// per frame around a cached child, not transitions.
  double markOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.byKey(kSplashMarkKey)).opacity;
  double markScale(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byKey(kSplashMarkKey),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .storage[0]; // the x scale; getMaxScaleOnAxis would see the untouched z

  /// The glow behind it.
  double glowOpacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byKey(kSplashGlowKey)).opacity.value;

  Future<BootstrapCubit> pumpSplash(
    WidgetTester tester, {
    required List<BootstrapStep> steps,
    Locale locale = const Locale('ar'),
  }) async {
    final cubit = BootstrapCubit(InitializeApp(steps));
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<BootstrapCubit>.value(
        value: cubit,
        child: const SplashScreen(),
      ),
      locale: locale,
      settle: false,
    );
    return cubit;
  }

  /// The entrance starts once the app's first frames are drawn: the frame
  /// after the first, then its first tick.
  Future<void> startEntrance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the mark over its glow, and no text at all', (
    tester,
  ) async {
    await pumpSplash(tester, steps: const []);

    expect(mark, findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('keeps the backdrop off the per-frame path', (tester) async {
    await pumpSplash(tester, steps: const []);
    await startEntrance(tester);
    await tester.pump(kLogoEntranceDuration);

    // The glow and the mark each sit under their own repaint boundary, so the
    // frames the breath drives re-composite them instead of re-painting the
    // gradient and the glow. Painting them every frame is what overran a
    // mid-range phone's frame budget (F27-P01).
    expect(
      find.ancestor(of: mark, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
    // Nothing paints a backdrop per frame any more.
    expect(
      find.byType(CustomPaint).evaluate().where((e) {
        final painter = (e.widget as CustomPaint).painter;
        return painter != null;
      }),
      isEmpty,
    );
  });

  testWidgets('labels the mark with the app name for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpSplash(tester, steps: const []);

    // Before the mark has even faded in.
    expect(find.bySemanticsLabel(ar.appName), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('announces the running launch stage as a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final session = Completer<Result<void, AppFailure>>();
    final cubit = await pumpSplash(
      tester,
      steps: [BootstrapStep(BootstrapStage.session, () => session.future)],
    );

    unawaited(cubit.start());
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel(ar.bootstrapStageSession)),
      isSemantics(label: ar.bootstrapStageSession, isLiveRegion: true),
    );

    session.complete(const Ok(null));
    await tester.pump();
    semantics.dispose();
  });

  testWidgets('labels the mark in English too', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSplash(tester, steps: const [], locale: const Locale('en'));

    expect(find.bySemanticsLabel(const EnStrings().appName), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows the error state with a retry action on failure', (
    tester,
  ) async {
    final cubit = await pumpSplash(
      tester,
      steps: [
        BootstrapStep(
          BootstrapStage.session,
          () async => const Err(NoInternetFailure()),
        ),
      ],
    );

    await cubit.start();
    await tester.pump();

    expect(find.text(ar.bootstrapErrorTitle), findsOneWidget);
    expect(find.text(ar.bootstrapErrorMessage), findsOneWidget);
    expect(find.text(ar.actionRetry), findsOneWidget);
    expect(mark, findsNothing);
  });

  testWidgets('tapping retry re-runs the launch sequence', (tester) async {
    var attempts = 0;
    final cubit = BootstrapCubit(
      InitializeApp([
        BootstrapStep(BootstrapStage.session, () async {
          attempts++;
          return const Err(NoInternetFailure());
        }),
      ]),
    );
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<BootstrapCubit>.value(
        value: cubit,
        child: const SplashScreen(),
      ),
      settle: false,
    );

    await cubit.start();
    await tester.pump();
    expect(attempts, 1);

    await tester.tap(find.text(ar.actionRetry));
    await tester.pump();

    expect(attempts, 2, reason: 'retry must re-run the sequence');
  });

  testWidgets('starts the entrance after the first frame, however slow', (
    tester,
  ) async {
    await pumpSplash(tester, steps: const []);

    // The app's first frames are its slowest. Time spent in them must not
    // be eaten out of the animation: the mark has not started appearing.
    await tester.pump(const Duration(milliseconds: 300));
    expect(markOpacity(tester), 0);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(markOpacity(tester), inExclusiveRange(0, 1));
  });

  testWidgets('fades the mark in while it grows from 0.90 to full size', (
    tester,
  ) async {
    await pumpSplash(tester, steps: const []);
    await startEntrance(tester);

    // The native splash before this one shows no mark, so it starts unseen.
    expect(markOpacity(tester), 0);
    expect(markScale(tester), 0.90);

    await tester.pump(const Duration(milliseconds: 400));
    expect(markOpacity(tester), inExclusiveRange(0, 1));
    expect(markScale(tester), inExclusiveRange(0.90, 1.1));

    // Settled by 0.75 s, well inside the 1.8 s entrance — full size, give or
    // take the breath it has already taken up.
    await tester.pump(const Duration(milliseconds: 400));
    expect(markOpacity(tester), 1);
    expect(markScale(tester), closeTo(1, 0.02));
  });

  testWidgets('paints every frame, and keeps breathing after the entrance', (
    tester,
  ) async {
    await pumpSplash(tester, steps: const []);
    await startEntrance(tester);

    for (var i = 0; i < 12; i++) {
      await tester.pump(kLogoEntranceDuration ~/ 10);
      expect(tester.takeException(), isNull);
    }

    // A slow launch keeps the splash up: the mark must still be moving.
    expect(tester.binding.hasScheduledFrame, isTrue);
    final before = markScale(tester);
    await tester.pump(kSplashBreathPeriod ~/ 4);
    expect(markScale(tester), isNot(before));
    expect(tester.takeException(), isNull);
    expect(mark, findsOneWidget);
  });

  testWidgets('the glow fades in once and then stops changing', (tester) async {
    await pumpSplash(tester, steps: const []);
    await startEntrance(tester);

    expect(glowOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 350));
    expect(glowOpacity(tester), inExclusiveRange(0, 1));

    // Settled well inside the entrance, and constant from then on — so the
    // layer it lives in is rasterised once and only re-composited after.
    await tester.pump(const Duration(milliseconds: 400));
    expect(glowOpacity(tester), 1);
    await tester.pump(const Duration(seconds: 2));
    expect(glowOpacity(tester), 1);
  });

  group('during the hand-off', () {
    Future<({AnimationController settle, AnimationController exit})>
    pumpInHandOff(WidgetTester tester, {bool reducedMotion = false}) async {
      final settle = AnimationController(
        vsync: const TestVSync(),
        duration: kSplashSettleDuration,
      );
      final exit = AnimationController(vsync: const TestVSync());
      addTearDown(settle.dispose);
      addTearDown(exit.dispose);
      final cubit = BootstrapCubit(InitializeApp(const []));
      addTearDown(cubit.close);

      await pumpApp(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: SplashPhases(
              settle: settle,
              exit: exit,
              child: BlocProvider<BootstrapCubit>.value(
                value: cubit,
                child: const SplashScreen(),
              ),
            ),
          ),
        ),
        settle: false,
      );
      return (settle: settle, exit: exit);
    }

    testWidgets('stills the breath over the settle, then stops asking for '
        'frames', (tester) async {
      const step = Duration(milliseconds: 50);
      final phases = await pumpInHandOff(tester);
      await startEntrance(tester);
      await tester.pump(kLogoEntranceDuration);

      // Breathing.
      var before = markScale(tester);
      await tester.pump(step);
      expect(markScale(tester), isNot(before));

      // Settled: the mark is at rest and nothing schedules frames, so the app
      // can be built under the splash with nothing on screen moving.
      unawaited(phases.settle.forward());
      await tester.pump();
      await tester.pump(kSplashSettleDuration);
      await tester.pump(const Duration(milliseconds: 16));

      before = markScale(tester);
      await tester.pump(step);
      expect(markScale(tester), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('grows the mark a little as the splash fades off', (
      tester,
    ) async {
      final phases = await pumpInHandOff(tester);
      await startEntrance(tester);
      await tester.pump(kLogoEntranceDuration);
      // Settled, so the breath is damped out and the scale is the exit's alone.
      phases.settle.value = 1;
      await tester.pump();
      expect(markScale(tester), closeTo(1, 0.001));

      phases.exit.value = 1;
      await tester.pump();
      expect(markScale(tester), closeTo(1.06, 0.001));
    });

    testWidgets('keeps the mark still under reduced motion', (tester) async {
      final phases = await pumpInHandOff(tester, reducedMotion: true);
      expect(markScale(tester), closeTo(1, 0.001));

      phases.exit.value = 1;
      await tester.pump();
      expect(markScale(tester), closeTo(1, 0.001));
    });
  });

  testWidgets('keeps the status bar icons light on the teal', (tester) async {
    await pumpSplash(tester, steps: const []);

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .ancestor(
            of: find.byType(Scaffold),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    );
    expect(region.value, SystemUiOverlayStyle.light);
  });

  testWidgets('draws the mark at the centre of the screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpSplash(tester, steps: const []);
    await tester.pump(kLogoEntranceDuration);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getSize(mark), const Size.square(kSplashMarkSize));
    expect(tester.getCenter(mark), screen.center(Offset.zero));
  });

  testWidgets('holds the splash until the entrance animation has played', (
    tester,
  ) async {
    // An empty sequence succeeds on the first frame, so only the hold can keep
    // the splash up.
    final cubit = BootstrapCubit(
      InitializeApp(const []),
      splashEntranceTimeout: kLogoEntranceDuration * 2,
    );
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<BootstrapCubit>.value(
        value: cubit,
        child: const SplashScreen(),
      ),
      settle: false,
    );

    unawaited(cubit.start());
    await tester.pump();
    expect(cubit.state, isA<BootstrapInProgress>());

    // Halfway through the entrance, so neither has the splash finished.
    await tester.pump(kLogoEntranceDuration ~/ 2);
    expect(cubit.state, isA<BootstrapInProgress>());

    // The whole animation, and only then the hand-off.
    await tester.pump(kLogoEntranceDuration);
    // (It completes once time has passed its end.)
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(cubit.state, isA<BootstrapSuccess>());
  });

  testWidgets('measures the hold from the first frame, not from launch', (
    tester,
  ) async {
    // A gap between `start()` and the first painted frame, as on a cold start:
    // a timer armed in the cubit would run out this much before the animation.
    final bootGap = kLogoEntranceDuration * 2 ~/ 3;

    final cubit = BootstrapCubit(
      InitializeApp(const []),
      splashEntranceTimeout: kLogoEntranceDuration * 2,
    );
    addTearDown(cubit.close);

    unawaited(cubit.start());
    await tester.pump(bootGap);

    await pumpApp(
      tester,
      BlocProvider<BootstrapCubit>.value(
        value: cubit,
        child: const SplashScreen(),
      ),
      settle: false,
    );

    // The animation has only just started, however long ago the launch did.
    await tester.pump(kLogoEntranceDuration - bootGap);
    expect(
      cubit.state,
      isA<BootstrapInProgress>(),
      reason: 'the boot gap must not eat into the animation',
    );

    // Past the end of the animation — the controller's first tick lands a frame
    // after `pumpWidget`, so pumping exactly the duration stops a hair short.
    await tester.pump(kLogoEntranceDuration);
    await tester.pump();
    expect(cubit.state, isA<BootstrapSuccess>());
  });

  testWidgets('under reduced motion, settles at once, keeps still, and '
      'releases the launch', (tester) async {
    final cubit = BootstrapCubit(
      InitializeApp(const []),
      splashEntranceTimeout: kLogoEntranceDuration * 2,
    );
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: BlocProvider<BootstrapCubit>.value(
            value: cubit,
            child: const SplashScreen(),
          ),
        ),
      ),
      settle: false,
    );

    unawaited(cubit.start());
    await tester.pump();
    await tester.pump();

    expect(
      cubit.state,
      isA<BootstrapSuccess>(),
      reason: 'reduced motion must not be made to sit through the hold',
    );
    // The settled frame, at once.
    expect(markOpacity(tester), 1);
    expect(markScale(tester), 1);
    // Nothing keeps ticking: the rings do not turn or pulse.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('surfaces a failure without waiting out the animation', (
    tester,
  ) async {
    final cubit = BootstrapCubit(
      InitializeApp([
        BootstrapStep(
          BootstrapStage.session,
          () async => const Err(NoInternetFailure()),
        ),
      ]),
      splashEntranceTimeout: kLogoEntranceDuration * 2,
    );
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<BootstrapCubit>.value(
        value: cubit,
        child: const SplashScreen(),
      ),
      settle: false,
    );

    unawaited(cubit.start());
    await tester.pump();

    expect(
      cubit.state,
      isA<BootstrapFailure>(),
      reason: 'an error must not sit behind the brand animation',
    );
  });

  testWidgets('lays out without overflow on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSplash(tester, steps: const []);
    await tester.pump(kLogoEntranceDuration);

    expect(tester.takeException(), isNull);
    expect(mark, findsOneWidget);
  });
}
