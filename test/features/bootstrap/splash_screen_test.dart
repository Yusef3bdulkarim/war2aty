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
import 'package:war2aty/features/bootstrap/presentation/screens/splash_screen.dart';
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
}
