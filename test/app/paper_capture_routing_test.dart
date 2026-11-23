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
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/papers/usecases/save_paper.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/platform/usecases/open_phone_dialer.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/usage/usage_hint_holder.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/check_capture_readiness.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/downscale_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/capture_gate_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
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
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/phone_dialer_cubit.dart';

import '../support/fakes.dart';
import '../support/voice_playback_rig.dart';

const _ar = ArStrings();
const _imagePath = '/tmp/paper.jpg';

/// T21's switch-over: crop → `/paper-waiting` → `/paper/:id?fresh=1` on
/// success or `/paper-failure` on failure, with system back on the waiting
/// screen leaving for Home — never back into the crop screen it replaced.
void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  Future<GoRouter> pump(
    WidgetTester tester, {
    FakeExplainRepository? explainRepo,
  }) async {
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
      DownscalePhoto(FakeImageDownscaler()),
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
      ..registerFactoryParam<ImagePreviewCubit, String, void>(
        (path, _) => ImagePreviewCubit(
          source: CapturedPhoto(path),
          rotate: RotateImage(FakeImageRotator()),
          cropImage: CropImage(FakeImageCropper()),
          cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
          speakFixedLine: SpeakFixedLine(FakeFixedLinePlayer()),
        ),
      )
      ..registerFactoryParam<PaperFailureCubit, PaperFailureKind, void>(
        (kind, _) => PaperFailureCubit(
          kind: kind,
          speakFixedLine: SpeakFixedLine(FakeFixedLinePlayer()),
        ),
      )
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
      ..registerFactory<CaptureGateCubit>(
        () => CaptureGateCubit(
          checkCaptureReadiness: CheckCaptureReadiness(
            FakeConnectivityService(),
            usage,
          ),
        ),
      )
      ..registerFactoryParam<PaperScreenCubit, String, void>(
        (paperId, _) => PaperScreenCubit(
          WatchPaper(FakePapersRepository()),
          LoadPaperImage(FakePaperImageStore()),
          paperId: paperId,
        ),
      )
      ..registerFactory<PhoneDialerCubit>(
        () => PhoneDialerCubit(OpenPhoneDialer(FakeExternalLinkService())),
      )
      ..registerFactory<VoicePlaybackCubit>(() {
        final rig = VoicePlaybackRig();
        addTearDown(rig.dispose);
        return rig.cubit;
      });

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

  testWidgets(
    'confirming the crop starts the explain run and lands on the paper',
    (tester) async {
      final router = await pump(tester);

      router.go(AppRoutes.previewWith(_imagePath));
      await _pumpMany(tester);

      await tester.tap(find.text(_ar.cropContinue));
      await _pumpMany(tester);

      expect(
        router.state.uri.toString(),
        AppRoutes.paperWith('p1', fresh: true),
      );
    },
  );

  testWidgets('a failing explain run lands on paper-failure', (tester) async {
    final router = await pump(
      tester,
      explainRepo: FakeExplainRepository(fails: true),
    );

    router.go(AppRoutes.previewWith(_imagePath));
    await _pumpMany(tester);

    await tester.tap(find.text(_ar.cropContinue));
    await _pumpMany(tester);

    expect(
      router.state.uri.toString(),
      AppRoutes.paperFailureWith(PaperFailureKind.serviceProblem),
    );
  });

  testWidgets('system back on the waiting screen goes to Home, not back '
      'into the crop screen', (tester) async {
    final explainRepo = FakeExplainRepository()..gate = Completer<void>();
    final router = await pump(tester, explainRepo: explainRepo);

    // Pushed on top of Home like the real flow does (Home → capture →
    // preview), rather than `go`-ing straight to it — otherwise Home's shell
    // is never mounted underneath and system back has nothing real to leave.
    unawaited(router.push(AppRoutes.previewWith(_imagePath)));
    await _pumpMany(tester);

    await tester.tap(find.text(_ar.cropContinue));
    await _pumpMany(tester);

    expect(router.state.uri.toString(), AppRoutes.paperWaiting);

    await tester.binding.handlePopRoute();
    await _pumpMany(tester);

    expect(router.state.uri.toString(), AppRoutes.home);

    explainRepo.gate!.complete();
    await tester.pump();
  });
}

/// Neither the crop screen nor the waiting screen ever settle — both run
/// continuous animations (the rotate hint bars; the scan line, wave bars and
/// dots) — so this suite drives them with explicit pumps instead of
/// `pumpAndSettle`, same as `image_preview_screen_test.dart` and
/// `paper_waiting_screen_test.dart` do.
Future<void> _pumpMany(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump();
  }
}

final class _SilentLogger implements AppLogger {
  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) {}

  @override
  void event(LogEvent e) {}
}
