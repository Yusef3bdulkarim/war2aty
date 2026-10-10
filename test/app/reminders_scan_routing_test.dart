import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/usecases/complete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/snooze_reminder.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminders.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/usage/usage_hint_holder.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/capture/domain/entities/capture_source.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/screens/camera_permission_gate.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminders_cubit.dart';

import '../support/fakes.dart';

/// F29-T11: «صوّر ورقة» on the empty reminders library opens the capture
/// flow.
///
/// The screen's own test can only prove the callback fires — which route it
/// fires *into* exists solely in `app_router.dart`, and the one thing that
/// can go wrong there is the same thing that can go wrong in «مستنداتي»'s
/// identical wiring: the gallery source instead of the camera, or a `go` that
/// loses the reminders tab the user came from.
void main() {
  const ar = ArStrings();

  setUp(getIt.reset);
  tearDown(getIt.reset);

  /// Boots the real router and lands on «التذكيرات» with nothing in it —
  /// the only state that draws «صوّر ورقة».
  Future<GoRouter> pumpEmptyReminders(WidgetTester tester) async {
    // A phone-shaped viewport, not the 800×600 default: the empty library is
    // tall, and on the default surface «صوّر ورقة» lands behind the shell's
    // nav bar, where no real user would ever be able to tap it.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final usage = FakeUsageRepository();
    addTearDown(usage.dispose);
    final recentDocuments = FakeRecentDocumentsRepository();
    addTearDown(recentDocuments.dispose);
    final upcomingReminders = FakeUpcomingReminderRepository();
    addTearDown(upcomingReminders.dispose);

    getIt
      // Home is `createAppRouter`'s own `initialLocation`, so the shell has
      // to be able to build before anything can navigate off it.
      ..registerFactory<HomeCubit>(
        () => HomeCubit(
          watchDailyUsage: WatchDailyUsage(usage),
          watchRecentDocuments: WatchRecentDocuments(recentDocuments),
          watchUpcomingReminder: WatchUpcomingReminder(upcomingReminders),
        ),
      )
      ..registerLazySingleton<UsageHintHolder>(UsageHintHolder.new)
      // An empty repository, which is what puts `_EmptyLibrary` on screen.
      ..registerFactory<RemindersCubit>(() {
        final reminders = FakeRemindersRepository();
        addTearDown(reminders.dispose);
        final scheduler = FakeReminderScheduler();
        return RemindersCubit(
          WatchReminders(reminders),
          CompleteReminder(reminders, scheduler),
          SnoozeReminder(reminders, scheduler),
        );
      })
      // Denied, so the camera route stops at its permission sheet instead of
      // reaching for a camera no test host has — and that sheet is itself
      // the proof the camera source, not the gallery, is what was asked for.
      ..registerFactory<CameraPermissionCubit>(() {
        final permissions = FakeCameraPermissionRepository(
          status: PermissionOutcome.denied,
        );
        return CameraPermissionCubit(
          getCameraPermission: GetCameraPermission(permissions),
          requestCameraPermission: RequestCameraPermission(permissions),
          openPermissionSettings: OpenPermissionSettings(permissions),
        );
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
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: AppLocalizations.arabic,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        routerConfig: router,
      ),
    );
    router.go(AppRoutes.reminders);
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('«صوّر ورقة» opens capture with the camera', (tester) async {
    final router = await pumpEmptyReminders(tester);
    expect(
      find.text(ar.reminderEmptyScanCta),
      findsOneWidget,
      reason: 'the empty library is the state under test',
    );

    await tester.tap(find.text(ar.reminderEmptyScanCta));
    await tester.pumpAndSettle();

    expect(
      router.state.uri.toString(),
      AppRoutes.captureWith(CaptureSource.camera),
    );
    // Not colour-blind to the source: the gallery route builds a picker, the
    // camera route a permission gate.
    expect(find.byType(CameraPermissionGate), findsOneWidget);
    expect(find.text(ar.cameraPermissionTitle), findsOneWidget);
  });

  testWidgets('it is pushed, so Back returns to «التذكيرات»', (tester) async {
    final router = await pumpEmptyReminders(tester);

    await tester.tap(find.text(ar.reminderEmptyScanCta));
    await tester.pumpAndSettle();
    // The user came to photograph a paper *for a reminder*; declining the
    // camera must not strand them on Home.
    await tester.tap(find.text(ar.actionBack));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.reminders);
    expect(find.text(ar.reminderEmptyScanCta), findsOneWidget);
  });
}
