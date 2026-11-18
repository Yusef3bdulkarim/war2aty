import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/capture/domain/entities/capture_source.dart';
import 'package:war2aty/features/capture/domain/usecases/check_capture_readiness.dart';
import 'package:war2aty/features/capture/presentation/cubit/capture_gate_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/capture_gate_state.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/home/presentation/screens/home_screen.dart';

import '../../support/fakes.dart';

const _ar = ArStrings();

CaptureGateCubit _gateCubit({
  bool connected = true,
  bool? explainEnabled = true,
}) => CaptureGateCubit(
  checkCaptureReadiness: CheckCaptureReadiness(
    FakeConnectivityService(connected: connected),
    FakeUsageRepository()..lastKnownExplainEnabled = explainEnabled,
  ),
);

HomeCubit _homeCubit() {
  final usage = FakeUsageRepository();
  final docs = FakeRecentDocumentsRepository();
  final reminders = FakeUpcomingReminderRepository();
  return HomeCubit(
    watchDailyUsage: WatchDailyUsage(usage),
    watchRecentDocuments: WatchRecentDocuments(docs),
    watchUpcomingReminder: WatchUpcomingReminder(reminders),
  )..start();
}

GoRouter _routerWith(CaptureGateCubit gate) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<HomeCubit>(create: (_) => _homeCubit()),
            BlocProvider<CaptureGateCubit>.value(value: gate),
          ],
          child: BlocListener<CaptureGateCubit, CaptureGateState>(
            listenWhen: (_, current) => current is! CaptureGateIdle,
            listener: (context, gateState) {
              switch (gateState) {
                case CaptureGateOpen(:final source):
                  context.push('/capture?source=${source.name}');
                case CaptureGateOffline(:final source):
                  context.push(
                    '/paper-failure?kind=offline&source=${source.name}',
                  );
                case CaptureGateServiceOff(:final source):
                  context.push(
                    '/paper-failure?kind=serviceProblem&source=${source.name}',
                  );
                case CaptureGateIdle():
                  break;
              }
            },
            child: Builder(
              builder: (context) => HomeScreen(
                onScan: () => context.read<CaptureGateCubit>().check(
                  CaptureSource.camera,
                ),
                onPickImage: () => context.read<CaptureGateCubit>().check(
                  CaptureSource.gallery,
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/capture',
        builder: (_, state) =>
            Text('capture:${state.uri.queryParameters['source']}'),
      ),
      GoRoute(
        path: '/paper-failure',
        builder: (_, state) => Text(
          'failure:${state.uri.queryParameters['kind']}'
          ':${state.uri.queryParameters['source']}',
        ),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      locale: AppLocalizations.arabic,
      theme: AppTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.delegates,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Home capture gate routing', () {
    testWidgets('ready → opens the capture route for the camera', (
      tester,
    ) async {
      final gate = _gateCubit();
      final router = _routerWith(gate);
      await _pump(tester, router);

      await tester.tap(find.text(_ar.homeScanTitle));
      await tester.pumpAndSettle();

      expect(find.text('capture:camera'), findsOneWidget);
    });

    testWidgets('ready → opens the capture route for the gallery', (
      tester,
    ) async {
      final gate = _gateCubit();
      final router = _routerWith(gate);
      await _pump(tester, router);

      await tester.tap(find.text(_ar.homePickImage));
      await tester.pumpAndSettle();

      expect(find.text('capture:gallery'), findsOneWidget);
    });

    testWidgets('offline → opens /paper-failure with kind=offline', (
      tester,
    ) async {
      final gate = _gateCubit(connected: false);
      final router = _routerWith(gate);
      await _pump(tester, router);

      await tester.tap(find.text(_ar.homeScanTitle));
      await tester.pumpAndSettle();

      expect(find.text('failure:offline:camera'), findsOneWidget);
    });

    testWidgets(
      'offline from gallery → carries the gallery source to the failure route',
      (tester) async {
        final gate = _gateCubit(connected: false);
        final router = _routerWith(gate);
        await _pump(tester, router);

        await tester.tap(find.text(_ar.homePickImage));
        await tester.pumpAndSettle();

        expect(find.text('failure:offline:gallery'), findsOneWidget);
      },
    );

    testWidgets('serviceOff → opens /paper-failure with kind=serviceProblem', (
      tester,
    ) async {
      final gate = _gateCubit(explainEnabled: false);
      final router = _routerWith(gate);
      await _pump(tester, router);

      await tester.tap(find.text(_ar.homeScanTitle));
      await tester.pumpAndSettle();

      expect(find.text('failure:serviceProblem:camera'), findsOneWidget);
    });
  });
}
