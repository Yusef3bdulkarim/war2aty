import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/papers/usecases/save_paper.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/usage/usage_hint_holder.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/features/capture/domain/entities/capture_source.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/check_capture_readiness.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/downscale_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/capture_gate_cubit.dart';
import 'package:war2aty/features/explain/domain/entities/paper_failure_kind.dart';
import 'package:war2aty/features/explain/domain/services/paper_explain_runner.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_and_save_paper.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_paper.dart';
import 'package:war2aty/features/explain/presentation/cubit/paper_failure_cubit.dart';
import 'package:war2aty/features/explain/presentation/cubit/paper_waiting_cubit.dart';
import 'package:war2aty/features/explain/presentation/paper_retry_holder.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';

import '../support/fakes.dart';

const _ar = ArStrings();
const _photo = CapturedPhoto('/tmp/retry.jpg');

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  Future<GoRouter> pump(
    WidgetTester tester, {
    FakeCaptureFileCleanup? cleanup,
    FakeExplainRepository? explainRepo,
  }) async {
    final theCleanup = cleanup ?? FakeCaptureFileCleanup();
    final theExplainRepo = explainRepo ?? FakeExplainRepository();
    final usage = FakeUsageRepository();
    addTearDown(usage.dispose);
    final recentDocuments = FakeRecentDocumentsRepository();
    addTearDown(recentDocuments.dispose);
    final upcomingReminders = FakeUpcomingReminderRepository();
    addTearDown(upcomingReminders.dispose);
    final perms = FakeCameraPermissionRepository(
      status: PermissionOutcome.denied,
    );

    final explainAndSave = ExplainAndSavePaper(
      DownscalePhoto(FakeImageDownscaler(output: _photo)),
      ExplainPaper(theExplainRepo),
      SavePaper(
        FakePapersRepository(),
        FakePaperImageStore(),
        idGenerator: () => 'p1',
      ),
      SyncDailyUsage(usage),
      CleanupCaptureFiles(FakeCaptureFileCleanup()),
      _SilentLogger(),
    );

    getIt
      ..registerFactory<HomeCubit>(
        () => HomeCubit(
          watchDailyUsage: WatchDailyUsage(usage),
          watchRecentDocuments: WatchRecentDocuments(recentDocuments),
          watchUpcomingReminder: WatchUpcomingReminder(upcomingReminders),
        ),
      )
      ..registerLazySingleton<UsageHintHolder>(UsageHintHolder.new)
      ..registerLazySingleton<PaperRetryHolder>(PaperRetryHolder.new)
      ..registerLazySingleton<PaperExplainRunner>(
        () => PaperExplainRunner(explainAndSave),
      )
      ..registerFactory<CleanupCaptureFiles>(
        () => CleanupCaptureFiles(theCleanup),
      )
      ..registerFactoryParam<PaperFailureCubit, PaperFailureKind, void>(
        (kind, _) => PaperFailureCubit(
          kind: kind,
          speakFixedLine: SpeakFixedLine(FakeFixedLinePlayer()),
        ),
      )
      // F39/F40-T21: `/paper-waiting` is now a real route, reached both from
      // the crop screen and from this suite's retry flow.
      ..registerFactoryParam<PaperWaitingCubit, CapturedPhoto?, void>(
        (photo, _) => PaperWaitingCubit(
          speakFixedLine: SpeakFixedLine(FakeFixedLinePlayer()),
          runner: getIt(),
          photo: photo,
        ),
      )
      ..registerFactory<CameraPermissionCubit>(
        () => CameraPermissionCubit(
          getCameraPermission: GetCameraPermission(perms),
          requestCameraPermission: RequestCameraPermission(perms),
          openPermissionSettings: OpenPermissionSettings(perms),
        ),
      )
      // Home's scan/pick controls build a `CaptureGateCubit` unconditionally
      // (F39/F40-T15) — not this suite's concern, but it must resolve for
      // Home to render at all (every test here lands on Home first).
      ..registerFactory<CaptureGateCubit>(
        () => CaptureGateCubit(
          checkCaptureReadiness: CheckCaptureReadiness(
            FakeConnectivityService(),
            usage,
          ),
        ),
      );

    final onboarding = OnboardingCubit(
      hasSeenOnboarding: HasSeenOnboarding(
        FakeOnboardingRepository(seen: true),
      ),
      completeOnboarding: CompleteOnboarding(
        FakeOnboardingRepository(seen: true),
      ),
    );
    await onboarding.load();

    final router = createAppRouter(onboardingGate: onboarding);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: AppLocalizations.arabic,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('kind routing', () {
    testWidgets('offline kind shows no-internet title', (tester) async {
      final router = await pump(tester);
      router.go(AppRoutes.paperFailureWith(PaperFailureKind.offline));
      await tester.pumpAndSettle();

      expect(find.text(_ar.analysisNoInternetTitle), findsOneWidget);
    });

    testWidgets('limitReached kind shows limit-reached title', (tester) async {
      final router = await pump(tester);
      router.go(AppRoutes.paperFailureWith(PaperFailureKind.limitReached));
      await tester.pumpAndSettle();

      expect(find.text(_ar.analysisLimitReachedTitle), findsOneWidget);
    });

    testWidgets('serviceProblem kind shows service-failed title', (
      tester,
    ) async {
      final router = await pump(tester);
      router.go(AppRoutes.paperFailureWith(PaperFailureKind.serviceProblem));
      await tester.pumpAndSettle();

      expect(find.text(_ar.analysisFailedTitle), findsOneWidget);
    });

    testWidgets('unknown kind redirects to home', (tester) async {
      final router = await pump(tester);
      unawaited(router.push('/paper-failure?kind=unknown'));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.home);
    });
  });

  group('after-photo retry', () {
    testWidgets('with holder photo: starts runner, clears holder', (
      tester,
    ) async {
      final explainRepo = FakeExplainRepository()..gate = Completer<void>();
      final router = await pump(tester, explainRepo: explainRepo);
      final holder = getIt<PaperRetryHolder>();
      final runner = getIt<PaperExplainRunner>();
      holder.photo = _photo;

      router.go(AppRoutes.paperFailureWith(PaperFailureKind.offline));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_ar.actionRetry));
      await tester.pump();

      expect(runner.isRunning, isTrue);
      expect(holder.photo, isNull);
    });
  });

  group('before-photo retry', () {
    testWidgets(
      'with no holder photo and camera source: navigates to capture',
      (tester) async {
        final router = await pump(tester);

        router.go(
          AppRoutes.paperFailureWith(
            PaperFailureKind.offline,
            source: CaptureSource.camera,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_ar.actionRetry));
        await tester.pumpAndSettle();

        expect(
          router.state.uri.toString(),
          AppRoutes.captureWith(CaptureSource.camera),
        );
      },
    );

    testWidgets('with no holder photo and no source: navigates home', (
      tester,
    ) async {
      final router = await pump(tester);

      router.go(AppRoutes.paperFailureWith(PaperFailureKind.offline));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_ar.actionRetry));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.home);
    });
  });

  group('leave (home button)', () {
    testWidgets('with holder photo: cleanup called, navigate home', (
      tester,
    ) async {
      final cleanup = FakeCaptureFileCleanup();
      final router = await pump(tester, cleanup: cleanup);
      final holder = getIt<PaperRetryHolder>();
      holder.photo = _photo;

      router.go(AppRoutes.paperFailureWith(PaperFailureKind.serviceProblem));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_ar.analysisBackToHome));
      await tester.pumpAndSettle();

      expect(cleanup.deleteCalls, [
        [_photo.path],
      ]);
      expect(router.state.uri.toString(), AppRoutes.home);
    });

    testWidgets('without holder photo: navigate home without cleanup', (
      tester,
    ) async {
      final cleanup = FakeCaptureFileCleanup();
      final router = await pump(tester, cleanup: cleanup);

      router.go(AppRoutes.paperFailureWith(PaperFailureKind.serviceProblem));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_ar.analysisBackToHome));
      await tester.pumpAndSettle();

      expect(cleanup.deleteCalls, isEmpty);
      expect(router.state.uri.toString(), AppRoutes.home);
    });
  });
}

final class _SilentLogger implements AppLogger {
  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) {}

  @override
  void event(LogEvent e) {}
}
