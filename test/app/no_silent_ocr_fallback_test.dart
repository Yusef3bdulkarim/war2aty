import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_image.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/assess_image_quality.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/correct_perspective.dart';
import 'package:war2aty/features/capture/domain/usecases/create_analysis_session.dart';
import 'package:war2aty/features/capture/domain/usecases/decide_analysis_route.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/ocr/domain/services/ocr_engine.dart';
import 'package:war2aty/features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';

import '../support/fakes.dart';

const _strings = ArStrings();
const _imagePath = '/tmp/paper.jpg';

/// Always fails, on either route — the online route is what this suite
/// exercises, but [analyze] is wired too, so a regression that routed a
/// retry through the offline path would show up as a non-zero count instead
/// of going unnoticed.
final class _AlwaysFailingAnalysisRepository implements AnalysisRepository {
  int analyzeCalls = 0;
  int analyzeImageCalls = 0;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    analyzeCalls++;
    return const Err(AnalysisServiceFailure());
  }

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyzeImage(
    AnalysisImageRequest request,
  ) async {
    analyzeImageCalls++;
    return const Err(AnalysisServiceFailure());
  }
}

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  late bool ocrEngineConstructed;
  late bool ocrProcessingCubitConstructed;

  /// Boots the real app — real DI wiring, real router — up to the point where
  /// a photo is ready to preview, with connectivity forced online (F13's
  /// [FakeConnectivityService] default) so [ImagePreviewCubit.proceed] takes
  /// the online branch.
  ///
  /// `OcrEngine` and `OcrProcessingCubit` are registered as poisoned: either
  /// one being resolved — which is the only way Tesseract can ever run —
  /// flips a flag this test asserts against, instead of letting a silent
  /// fallback pass unnoticed.
  Future<_AlwaysFailingAnalysisRepository> pumpToOnlinePreview(
    WidgetTester tester,
  ) async {
    ocrEngineConstructed = false;
    ocrProcessingCubitConstructed = false;

    final onboarding = FakeOnboardingRepository(seen: true);
    // azureOcrEnabled: true — this test exercises the online route
    // specifically (its whole point is proving no silent OCR fallback once
    // online is chosen), so the pipeline must actually be live.
    final usage = FakeUsageRepository(
      seed: usageWith(limit: 3, remaining: 3, azureOcrEnabled: true),
    );
    addTearDown(usage.dispose);
    final documents = FakeRecentDocumentsRepository();
    addTearDown(documents.dispose);
    final reminders = FakeUpcomingReminderRepository();
    addTearDown(reminders.dispose);
    final repository = _AlwaysFailingAnalysisRepository();

    getIt
      ..registerFactory<LocaleCubit>(() {
        final store = FakeLocaleStore();
        return LocaleCubit(
          getSavedLocale: GetSavedLocale(store),
          setLocale: SetLocale(store),
        );
      })
      ..registerFactory<BootstrapCubit>(
        () => BootstrapCubit(InitializeApp(const [])),
      )
      ..registerLazySingleton<OnboardingCubit>(
        () => OnboardingCubit(
          hasSeenOnboarding: HasSeenOnboarding(onboarding),
          completeOnboarding: CompleteOnboarding(onboarding),
        ),
      )
      ..registerFactory<HomeCubit>(
        () => HomeCubit(
          watchDailyUsage: WatchDailyUsage(usage),
          watchRecentDocuments: WatchRecentDocuments(documents),
          watchUpcomingReminder: WatchUpcomingReminder(reminders),
        ),
      )
      // Online by default (`FakeConnectivityService`'s default is connected),
      // a corrector that hands the photo back untouched, good-quality fakes
      // for rotate/assess so `confirm()` proceeds without the quality sheet.
      ..registerFactoryParam<ImagePreviewCubit, String, void>(
        (path, _) => ImagePreviewCubit(
          source: CapturedPhoto(path),
          rotate: RotateImage(FakeImageRotator()),
          assessQuality: AssessImageQuality(FakeImageQualityService()),
          decideRoute: DecideAnalysisRoute(FakeConnectivityService(), usage),
          correctPerspective: CorrectPerspective(FakePerspectiveCorrector()),
          createSession: CreateAnalysisSession(FakeAnalysisSessionStorage()),
          onlineHandoff: getIt(),
          ocrHandoff: getIt(),
          cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
        ),
      )
      ..registerLazySingleton<ImageAnalysisSessionHolder>(
        ImageAnalysisSessionHolder.new,
      )
      ..registerLazySingleton<OcrSessionHolder>(OcrSessionHolder.new)
      ..registerLazySingleton<AnalysisRepository>(() => repository)
      ..registerFactory<AnalyzeDocument>(() => AnalyzeDocument(getIt()))
      ..registerFactory<AnalyzeImage>(() => AnalyzeImage(getIt()))
      ..registerFactory<BuildAnalysisResult>(BuildAnalysisResult.new)
      ..registerFactoryParam<
        AnalysisResultCubit,
        AnalysisSession,
        AnalysisSource
      >(
        (session, source) => AnalysisResultCubit(
          session: session,
          source: source,
          analyzeDocument: getIt(),
          analyzeImage: getIt(),
          buildResult: getIt(),
        ),
      )
      // Poisoned (F13-T16): the online route must never reach either of
      // these, whether on the first attempt or on any retry.
      ..registerLazySingleton<OcrEngine>(() {
        ocrEngineConstructed = true;
        throw StateError(
          'OcrEngine/Tesseract must never be constructed once the online '
          'route is chosen — a failure must retry the online request, not '
          'fall back to on-device OCR.',
        );
      })
      ..registerFactoryParam<OcrProcessingCubit, AnalysisSession, void>((_, _) {
        ocrProcessingCubitConstructed = true;
        throw StateError(
          'OcrProcessingCubit must never be constructed once the online '
          'route is chosen — the /ocr route must not be reachable from a '
          'failed online analysis.',
        );
      })
      ..registerLazySingleton<GoRouter>(
        () => createAppRouter(onboardingGate: getIt()),
      );

    await tester.pumpWidget(const WaraqtiApp());
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('a failed online analysis never constructs Tesseract, even after '
      'retrying repeatedly', (tester) async {
    final repository = await pumpToOnlinePreview(tester);

    getIt<GoRouter>().go(AppRoutes.previewWith(_imagePath));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_strings.previewUseImage));
    await tester.pumpAndSettle();

    // Landed on the failure page over the online (image) route, never the
    // OCR screen.
    expect(find.text(_strings.analysisFailedTitle), findsOneWidget);
    expect(getIt<GoRouter>().state.uri.toString(), AppRoutes.result);
    expect(repository.analyzeImageCalls, 1);
    expect(repository.analyzeCalls, 0);

    // Retrying stays on the same failing online request — not a fallback.
    await tester.tap(find.text(_strings.actionRetry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_strings.actionRetry));
    await tester.pumpAndSettle();

    expect(repository.analyzeImageCalls, 3);
    expect(repository.analyzeCalls, 0);
    expect(getIt<GoRouter>().state.uri.toString(), AppRoutes.result);
    expect(
      ocrEngineConstructed,
      isFalse,
      reason: 'Tesseract must never be constructed on a failed online run',
    );
    expect(ocrProcessingCubitConstructed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
