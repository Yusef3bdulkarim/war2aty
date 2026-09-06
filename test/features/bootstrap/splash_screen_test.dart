import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:war2aty/features/bootstrap/presentation/widgets/paper_plane_logo.dart';
import 'package:war2aty/features/bootstrap/presentation/widgets/pulsing_dots.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

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

  testWidgets('shows brand splash with tagline and progress dots', (
    tester,
  ) async {
    await pumpSplash(tester, steps: const []);

    expect(find.text(ar.appName), findsOneWidget);
    expect(find.text(ar.appTagline), findsOneWidget);
    expect(find.byType(PulsingDots), findsOneWidget);
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
    expect(find.byType(PulsingDots), findsNothing);
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

  testWidgets('renders in English too', (tester) async {
    await pumpSplash(tester, steps: const [], locale: const Locale('en'));

    expect(find.text(const EnStrings().appTagline), findsOneWidget);
  });

  testWidgets('animates the mark through the whole entrance', (tester) async {
    await pumpSplash(tester, steps: const []);

    expect(find.byType(PaperPlaneLogo), findsOneWidget);

    // Walk the entrance in steps: every frame must paint without throwing,
    // whatever stage of the flight/unfold/settle it lands on.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }

    // The ambient loop takes over once the entrance is done.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(PaperPlaneLogo), findsOneWidget);
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

    // Still mid-flight: the mark has not finished, so neither has the splash.
    await tester.pump(kLogoEntranceDuration ~/ 2);
    expect(cubit.state, isA<BootstrapInProgress>());

    // The whole animation, and only then the hand-off.
    await tester.pump(kLogoEntranceDuration);
    await tester.pump();
    expect(cubit.state, isA<BootstrapSuccess>());
  });

  testWidgets('measures the hold from the first frame, not from launch', (
    tester,
  ) async {
    // The gap a cold start opens between `start()` and the first painted frame:
    // a timer armed in the cubit would run out this much before the animation.
    const bootGap = Duration(milliseconds: 2500);

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

  testWidgets('under reduced motion, settles at once and releases the launch', (
    tester,
  ) async {
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
    // The mark is drawn settled rather than mid-flight.
    expect(find.text(ar.appName), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text(ar.appName),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      1.0,
    );
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
    await tester.pump(const Duration(milliseconds: 2400));

    expect(tester.takeException(), isNull);
    expect(find.text(ar.appName), findsOneWidget);
  });
}
