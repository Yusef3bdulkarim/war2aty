import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/app/shell/scaffold_with_nav_bar.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import 'package:war2aty/features/capture/domain/entities/capture_source.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/pick_image_from_gallery.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/gallery_picker_cubit.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';

import '../support/fakes.dart';

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  /// Boots the real app widget. [onboarded] seeds the first-run flag.
  Future<void> pumpShell(
    WidgetTester tester, {
    String? persisted,
    bool onboarded = true,
  }) async {
    final onboarding = FakeOnboardingRepository(seen: onboarded);
    final usage = FakeUsageRepository();
    addTearDown(usage.dispose);
    final documents = FakeRecentDocumentsRepository();
    addTearDown(documents.dispose);
    final reminders = FakeUpcomingReminderRepository();
    addTearDown(reminders.dispose);
    getIt
      ..registerFactory<LocaleCubit>(() {
        final store = FakeLocaleStore(persisted);
        return LocaleCubit(
          getSavedLocale: GetSavedLocale(store),
          setLocale: SetLocale(store),
        );
      })
      // An empty launch sequence succeeds immediately, so the shell is shown.
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
      // Denied, so tapping «صوّر ورقتك» lands on the permission sheet — the
      // state a first-time user is actually in.
      ..registerFactory<CameraPermissionCubit>(() {
        final permissions = FakeCameraPermissionRepository(
          status: PermissionOutcome.denied,
        );
        return CameraPermissionCubit(
          getCameraPermission: GetCameraPermission(permissions),
          requestCameraPermission: RequestCameraPermission(permissions),
          openPermissionSettings: OpenPermissionSettings(permissions),
        );
      })
      // The picker is held open (never completes), so navigating into the
      // gallery route stays there instead of immediately popping on a result.
      ..registerFactory<GalleryPickerCubit>(
        () => GalleryPickerCubit(
          pickImageFromGallery: PickImageFromGallery(
            FakeImagePickerService()..gate = Completer<void>(),
          ),
        ),
      )
      ..registerLazySingleton<GoRouter>(
        () => createAppRouter(onboardingGate: getIt()),
      );
    await tester.pumpWidget(const WaraqtiApp());
    await tester.pumpAndSettle();
  }

  TextDirection navDirection(WidgetTester tester) =>
      Directionality.of(tester.element(find.byType(ScaffoldWithNavBar)));

  /// The design's bar is custom-drawn, so it is found by its shell widget
  /// rather than by Material's [NavigationBar].
  Finder navBar() => find.byType(ScaffoldWithNavBar);

  testWidgets('boots to a 4-tab shell in Arabic (RTL)', (tester) async {
    await pumpShell(tester);
    const ar = ArStrings();

    expect(navBar(), findsOneWidget);
    expect(find.text(ar.navHome), findsWidgets);
    expect(find.text(ar.navDocuments), findsWidgets);
    expect(find.text(ar.navReminders), findsWidgets);
    expect(find.text(ar.navSettings), findsWidgets);
    expect(navDirection(tester), TextDirection.rtl);
  });

  testWidgets('boots in English (LTR) when that language is persisted', (
    tester,
  ) async {
    await pumpShell(tester, persisted: 'en');
    const en = EnStrings();

    expect(find.text(en.navHome), findsWidgets);
    expect(find.text(en.navSettings), findsWidgets);
    expect(navDirection(tester), TextDirection.ltr);
  });

  group('into capture', () {
    const ar = ArStrings();

    testWidgets('the scan card opens capture with the camera', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text(ar.homeScanTitle));
      await tester.pumpAndSettle();

      expect(
        getIt<GoRouter>().state.uri.toString(),
        AppRoutes.captureWith(CaptureSource.camera),
      );
    });

    testWidgets('«اختار صورة» opens capture with the gallery', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text(ar.homePickImage));
      // The gallery route holds a spinner behind the system picker, which never
      // settles — pump frames rather than settling.
      await tester.pump();
      await tester.pump();

      expect(
        getIt<GoRouter>().state.uri.toString(),
        AppRoutes.captureWith(CaptureSource.gallery),
      );
    });

    testWidgets('capture takes the whole screen, without the nav bar', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text(ar.homeScanTitle));
      await tester.pumpAndSettle();

      // Scanning is a task to finish and leave, not a place to browse.
      expect(navBar(), findsNothing);
    });

    testWidgets('the camera asks permission before anything else', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text(ar.homeScanTitle));
      await tester.pumpAndSettle();

      expect(find.text(ar.cameraPermissionTitle), findsOneWidget);
    });

    testWidgets('declining the camera offers the gallery instead', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text(ar.homeScanTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.cameraPermissionPickInstead));
      // Lands on the gallery route's spinner, which never settles.
      await tester.pump();
      await tester.pump();

      expect(
        getIt<GoRouter>().state.uri.toString(),
        AppRoutes.captureWith(CaptureSource.gallery),
      );
    });

    testWidgets('leaving capture returns to Home, not out of the app', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text(ar.homeScanTitle));
      await tester.pumpAndSettle();

      // The pushed screen must offer a way back rather than trapping the user.
      await tester.tap(find.text(ar.actionBack));
      await tester.pumpAndSettle();

      expect(navBar(), findsOneWidget);
      expect(find.text(ar.homeGreetingTitle), findsOneWidget);
    });
  });

  group('first-run gate', () {
    const ar = ArStrings();

    testWidgets('a first run opens onboarding instead of the shell', (
      tester,
    ) async {
      await pumpShell(tester, onboarded: false);

      expect(find.text(ar.onboardingTitle), findsOneWidget);
      expect(navBar(), findsNothing);
    });

    testWidgets('finishing onboarding lands on the shell', (tester) async {
      await pumpShell(tester, onboarded: false);

      await tester.tap(find.text(ar.onboardingStart));
      await tester.pumpAndSettle();
      expect(find.text(ar.privacyTitle), findsOneWidget);

      await tester.tap(find.text(ar.privacyAgree));
      await tester.pumpAndSettle();

      expect(navBar(), findsOneWidget);
      expect(find.text(ar.privacyTitle), findsNothing);
    });

    testWidgets('a returning user never sees onboarding', (tester) async {
      await pumpShell(tester);

      expect(find.text(ar.onboardingTitle), findsNothing);
      expect(navBar(), findsOneWidget);
    });
  });
}
