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
import 'package:war2aty/features/bootstrap/presentation/screens/launch_screen.dart';

import '../../support/pump_app.dart';
import '../../support/ui_audit.dart';

/// F28-T02. These cover what survived the purge of the old splash, not a new
/// design: the launch screen's state switch, the launch failure's retry, and
/// the two accessibility affordances that are behaviour rather than decoration.
///
/// Everything about how the launch *looks* is deliberately untested here —
/// F28-T06 brings the design and F28-T08 the suite that pins it. What is
/// asserted below should still hold whatever that design turns out to be.
void main() {
  const ar = ArStrings();

  Future<BootstrapCubit> pumpLaunch(
    WidgetTester tester, {
    required List<BootstrapStep> steps,
    Locale locale = const Locale('ar'),
    TextScaler? textScaler,
  }) async {
    final cubit = BootstrapCubit(InitializeApp(steps));
    addTearDown(cubit.close);

    await pumpApp(
      tester,
      BlocProvider<BootstrapCubit>.value(
        value: cubit,
        child: const LaunchScreen(),
      ),
      locale: locale,
      textScaler: textScaler,
      settle: false,
    );
    return cubit;
  }

  auditScreenLayout('LaunchScreen', (tester, locale, scaler) async {
    await pumpLaunch(
      tester,
      steps: const [],
      locale: locale,
      textScaler: scaler,
    );
    await tester.pump();
  });

  auditScreenLayout('LaunchErrorScreen', (tester, locale, scaler) async {
    final cubit = await pumpLaunch(
      tester,
      steps: [
        BootstrapStep(
          BootstrapStage.session,
          () async => const Err(NoInternetFailure()),
        ),
      ],
      locale: locale,
      textScaler: scaler,
    );
    await cubit.start();
    await tester.pump();
  });

  testWidgets('paints the native splash colour, so the handover is invisible', (
    tester,
  ) async {
    await pumpLaunch(tester, steps: const []);
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.backgroundColor,
      kLaunchBackground,
      reason:
          'the native splash shows kLaunchBackground; if the first Flutter '
          'frame is any other colour the swap between them is visible',
    );
  });

  testWidgets('carries no text while launching', (tester) async {
    await pumpLaunch(tester, steps: const []);
    await tester.pump();

    expect(
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').isNotEmpty),
      findsNothing,
      reason: 'the launch frame is logo-only by decision 5 of F28',
    );
  });

  testWidgets('announces the app name to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpLaunch(tester, steps: const []);

    expect(find.bySemanticsLabel(ar.appName), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('announces the app name in English too', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpLaunch(tester, steps: const [], locale: const Locale('en'));

    expect(find.bySemanticsLabel(const EnStrings().appName), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('announces the running launch stage as a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final session = Completer<Result<void, AppFailure>>();
    final cubit = await pumpLaunch(
      tester,
      steps: [BootstrapStep(BootstrapStage.session, () => session.future)],
    );

    unawaited(cubit.start());
    // Twice: the first pump is when the stage reaches the cubit, and the
    // rebuild it triggers lands on the frame after. The old splash hid this —
    // its animation controller always had a frame pending, so one pump was
    // enough; a screen that draws nothing moving has no such frame coming.
    await tester.pump();
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel(ar.bootstrapStageSession)),
      isSemantics(label: ar.bootstrapStageSession, isLiveRegion: true),
    );

    session.complete(const Ok(null));
    await tester.pump();
    semantics.dispose();
  });

  testWidgets('keeps the status bar icons light on the teal', (tester) async {
    await pumpLaunch(tester, steps: const []);
    await tester.pump();

    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value,
      SystemUiOverlayStyle.light,
    );
  });

  testWidgets('shows the error state with a retry action on failure', (
    tester,
  ) async {
    final cubit = await pumpLaunch(
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
  });

  testWidgets('tapping retry re-runs the launch sequence', (tester) async {
    var attempts = 0;
    final cubit = await pumpLaunch(
      tester,
      steps: [
        BootstrapStep(BootstrapStage.session, () async {
          attempts++;
          return const Err(NoInternetFailure());
        }),
      ],
    );

    await cubit.start();
    await tester.pump();
    expect(attempts, 1);

    await tester.tap(find.text(ar.actionRetry));
    await tester.pump();

    expect(attempts, 2, reason: 'retry must re-run the sequence');
  });
}
