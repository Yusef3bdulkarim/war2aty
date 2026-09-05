import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/documents/usecases/delete_document.dart';
import 'package:war2aty/core/documents/usecases/set_document_note.dart';
import 'package:war2aty/core/documents/usecases/update_document.dart';
import 'package:war2aty/core/documents/usecases/watch_document.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/request_notification_permission.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/usage/usage_hint_holder.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/core/widgets/date_selection_sheet.dart';
import 'package:war2aty/core/widgets/result_action_bar.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_raw_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_form_cubit.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_from_document_args.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminder_form_screen.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/document_details_cubit.dart';

import '../support/fakes.dart';

/// Regression test for a `ProviderNotFoundException` that only reproduces
/// through the real router: `documentDetails`'s `onCreateReminder` callback
/// used to be built from the route builder's own `context`, which sits
/// *above* `BlocProvider<DocumentDetailsCubit>` rather than below it — see
/// `app_router.dart`'s `documentDetails` `GoRoute`.
///
/// Neither `document_details_screen_test.dart` (pumps the screen under a
/// provider it supplies directly) nor `document_details_cubit_test.dart`
/// (never touches routing) can catch this — only navigating through
/// `createAppRouter` itself, the way the app really does, exercises the
/// broken wiring.
void main() {
  const ar = ArStrings();

  setUp(getIt.reset);
  tearDown(getIt.reset);

  /// Boots the real router at Home (its hardcoded `initialLocation`), then
  /// jumps straight to a saved document's details — the same route a tap on
  /// a documents-list row or a reminder's linked-document row lands on.
  Future<GoRouter> pumpDocumentDetails(
    WidgetTester tester, {
    required FakeDocumentsRepository documents,
    required String documentId,
  }) async {
    final usage = FakeUsageRepository();
    addTearDown(usage.dispose);
    final recentDocuments = FakeRecentDocumentsRepository();
    addTearDown(recentDocuments.dispose);
    final upcomingReminders = FakeUpcomingReminderRepository();
    addTearDown(upcomingReminders.dispose);
    final tts = FakeTextToSpeechService();
    addTearDown(tts.dispose);

    getIt
      // The shell's Home tab is what `createAppRouter`'s `initialLocation`
      // builds first — needed to reach the router at all, unrelated to the
      // bug itself.
      ..registerFactory<HomeCubit>(
        () => HomeCubit(
          watchDailyUsage: WatchDailyUsage(usage),
          watchRecentDocuments: WatchRecentDocuments(recentDocuments),
          watchUpcomingReminder: WatchUpcomingReminder(upcomingReminders),
        ),
      )
      ..registerFactoryParam<DocumentDetailsCubit, String, void>(
        (id, _) => DocumentDetailsCubit(
          WatchDocument(documents),
          const BuildAnalysisResult(),
          SetDocumentNote(documents),
          UpdateDocument(documents),
          DeleteDocument(documents),
          documentId: id,
        ),
      )
      // The details route now also provides an `AudioReaderCubit` alongside
      // `DocumentDetailsCubit` (F08 follow-up, mirroring `/result`) — needed
      // to reach the route at all, unrelated to the bug itself.
      ..registerFactory<AudioReaderCubit>(
        () => AudioReaderCubit(
          StartReading(
            const BuildReadingText(),
            const SelectVoiceForReading(),
            tts,
          ),
          StartRawReading(const SelectVoiceForReading(), tts),
          StopReading(tts),
          PauseReading(tts),
          ResumeReading(tts),
          SetReadingSpeed(tts),
          WatchReadingEvents(tts),
          GetDefaultReadingSpeed(FakeDefaultReadingSpeedStore()),
          GetDefaultReadingVoice(FakeDefaultReadingVoiceStore()),
        ),
      )
      ..registerLazySingleton<UsageHintHolder>(UsageHintHolder.new)
      ..registerFactoryParam<ReminderFormCubit, ReminderFromDocumentArgs, void>(
        (args, _) {
          final reminders = FakeRemindersRepository();
          addTearDown(reminders.dispose);
          final scheduler = FakeReminderScheduler();
          final permissions = FakeNotificationPermissionRepository();
          return ReminderFormCubit.fromDocument(
            createFromDocumentDate: CreateReminderFromDocumentDate(
              reminders,
              scheduler,
            ),
            createManual: CreateManualReminder(reminders, scheduler),
            getNotificationPermission: GetNotificationPermission(permissions),
            requestNotificationPermission: RequestNotificationPermission(
              permissions,
            ),
            args: args,
          );
        },
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
    router.go(AppRoutes.documentDetailsWith(documentId));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'creating a reminder from a saved document with several dates reaches '
    'the reminder form instead of throwing ProviderNotFoundException',
    (tester) async {
      final documents = FakeDocumentsRepository();
      addTearDown(documents.dispose);
      documents.emitDocument(
        savedDocumentWith(
          dates: [
            AnalysisDate(
              label: 'موعد السداد',
              date: DateTime(2026, 8, 25),
              role: DateRole.deadline,
              isReminderWorthy: true,
              confidence: ConfidenceBand.high,
            ),
            AnalysisDate(
              label: 'تاريخ إصدار الفاتورة',
              date: DateTime(2026, 8),
              role: DateRole.issued,
              isReminderWorthy: false,
              confidence: ConfidenceBand.high,
            ),
          ],
        ),
      );

      final router = await pumpDocumentDetails(
        tester,
        documents: documents,
        documentId: 'doc-1',
      );

      // The details screen now shows «إنشاء تذكير» in two places (the
      // bottom action bar and the dates card) — the bar's is the always-on
      // entry point, so that is the one this test drives.
      await tester.tap(
        find.descendant(
          of: find.byType(ResultActionBar),
          matching: find.text(ar.resultCreateReminder),
        ),
      );
      await tester.pumpAndSettle();

      // Two dates: the picking sheet must appear rather than the app
      // choosing on the user's behalf (UX rule §5.8).
      expect(find.text(ar.resultPickDateTitle), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(DateSelectionSheet),
          matching: find.text('موعد السداد'),
        ),
      );
      await tester.pumpAndSettle();

      // Before the fix this line was never reached: the tap above threw
      // ProviderNotFoundException instead. Reaching the reminder form is
      // proof the callback read `DocumentDetailsCubit` successfully.
      expect(router.state.uri.toString(), AppRoutes.reminderCreate);
      expect(find.byType(ReminderFormScreen), findsOneWidget);
    },
  );
}
