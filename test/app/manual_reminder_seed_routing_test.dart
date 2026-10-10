import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/request_notification_permission.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/time/document_date_label.dart';
import 'package:war2aty/core/usage/usage_hint_holder.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_cubit.dart';
import 'package:war2aty/features/reminders/presentation/models/manual_reminder_seed.dart';

import '../support/fakes.dart';

/// F29-T06: `/reminders/manual` carries an optional [ManualReminderSeed].
///
/// Only the real router exercises this. The cubit's own test covers what a
/// seed *does* once it reaches the cubit; what can go wrong here is the
/// plumbing between them — a `param1` that never leaves the route, a get_it
/// registration that rejects a null parameter, or an `extra` of the wrong
/// type crashing a screen the header button reaches with none at all.
void main() {
  const ar = ArStrings();

  setUp(getIt.reset);
  tearDown(getIt.reset);

  /// Boots the real router and goes to the manual reminder form, optionally
  /// handing it [seed] the way a quick row does.
  Future<void> pumpManualForm(WidgetTester tester, {Object? extra}) async {
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
      // The registration under test, shaped exactly as `service_locator.dart`
      // shapes it: a factory parameterised on a **nullable** seed, told apart
      // from the from-document one by `instanceName`.
      ..registerFactoryParam<ReminderFormCubit, ManualReminderSeed?, void>((
        seed,
        _,
      ) {
        final reminders = FakeRemindersRepository();
        addTearDown(reminders.dispose);
        final scheduler = FakeReminderScheduler();
        final permissions = FakeNotificationPermissionRepository();
        return ReminderFormCubit.manual(
          createFromDocumentDate: CreateReminderFromDocumentDate(
            reminders,
            scheduler,
          ),
          createManual: CreateManualReminder(reminders, scheduler),
          getNotificationPermission: GetNotificationPermission(permissions),
          requestNotificationPermission: RequestNotificationPermission(
            permissions,
          ),
          seed: seed,
        );
      }, instanceName: manualReminderFormInstanceName);

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
    router.go(AppRoutes.reminderManual, extra: extra);
    await tester.pumpAndSettle();
  }

  testWidgets('a seed reaches the form through the route', (tester) async {
    await pumpManualForm(
      tester,
      extra: ManualReminderSeed(
        eventDate: DateTime(2026, 10, 13),
        eventMinuteOfDay: 9 * 60,
      ),
    );

    // Asserted as the user sees it — the date and time the picker rows show,
    // not the cubit's fields.
    expect(
      find.text(formatDocumentDate(ar, DateTime(2026, 10, 13))),
      findsOneWidget,
    );
    expect(find.text(formatWallClockTime(ar, 9, 0)), findsOneWidget);

    // The hint is gone from both rows, which is what "already filled in"
    // looks like.
    expect(find.text(ar.reminderDatePickHint), findsNothing);
    expect(find.text(ar.reminderTimePickHint), findsNothing);
  });

  testWidgets('no extra still opens the empty form the header button gets', (
    tester,
  ) async {
    // «إضافة تذكير» passes nothing. A nullable `param1` is what lets this
    // through get_it rather than throwing on a missing parameter.
    await pumpManualForm(tester);

    expect(find.text(ar.reminderDatePickHint), findsOneWidget);
    expect(find.text(ar.reminderTimePickHint), findsOneWidget);
  });

  testWidgets('an extra of the wrong type opens the empty form, not Home', (
    tester,
  ) async {
    // Unlike every other route in `app_router.dart` that reads an `extra`,
    // this one must not bounce to Home when it cannot use what it was given:
    // an empty manual form is a perfectly good destination, and the user
    // asked for the form.
    await pumpManualForm(tester, extra: 'not a seed');

    expect(find.text(ar.reminderAddAction), findsWidgets);
    expect(find.text(ar.reminderDatePickHint), findsOneWidget);
  });
}
