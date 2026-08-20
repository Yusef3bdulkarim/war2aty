import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/get_processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/set_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/set_processing_mode.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/audio/usecases/get_resume_reading_enabled.dart';
import 'package:war2aty/core/audio/usecases/preview_default_voice.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/set_resume_reading_enabled.dart';
import 'package:war2aty/core/documents/usecases/delete_all_documents.dart';
import 'package:war2aty/core/env/app_environment.dart';
import 'package:war2aty/core/env/usecases/get_app_version.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/open_notification_permission_settings.dart';
import 'package:war2aty/core/reminders/usecases/delete_all_reminders.dart';
import 'package:war2aty/core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import 'package:war2aty/core/reminders/usecases/set_hide_sensitive_notification_details.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/settings/usecases/delete_all_app_data.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:war2aty/features/settings/presentation/cubit/settings_state.dart';

import '../../../../support/fakes.dart';

const _ar = ArStrings();

void main() {
  // Builds a cubit over fake stores and registers its close() teardown.
  SettingsCubit buildCubit({
    FakeAnalysisConsentStore? consentStore,
    FakeProcessingModeStore? modeStore,
    FakeDefaultReadingSpeedStore? speedStore,
    FakeDefaultReadingVoiceStore? voiceStore,
    FakeResumeReadingEnabledStore? resumeStore,
    FakeTextToSpeechService? tts,
    FakeCameraPermissionRepository? cameraPermissionRepo,
    FakeNotificationPermissionRepository? notificationPermissionRepo,
    FakeNotificationPrivacyStore? notificationPrivacyStore,
    FakeDocumentsRepository? documentsRepository,
    FakeRemindersRepository? remindersRepository,
    FakeReminderScheduler? reminderScheduler,
    FakeAppSettingsRepository? settingsRepository,
    FakeUsageRepository? usageRepository,
    String appVersion = '1.0.0',
  }) {
    final consent = consentStore ?? FakeAnalysisConsentStore();
    final mode = modeStore ?? FakeProcessingModeStore();
    final speed = speedStore ?? FakeDefaultReadingSpeedStore();
    final voice = voiceStore ?? FakeDefaultReadingVoiceStore();
    final resume = resumeStore ?? FakeResumeReadingEnabledStore();
    final ttsService = tts ?? FakeTextToSpeechService();
    final cameraPermission =
        cameraPermissionRepo ??
        FakeCameraPermissionRepository(status: PermissionOutcome.granted);
    final notificationPermission =
        notificationPermissionRepo ?? FakeNotificationPermissionRepository();
    final notificationPrivacy =
        notificationPrivacyStore ?? FakeNotificationPrivacyStore();
    final documents = documentsRepository ?? FakeDocumentsRepository();
    final reminders = remindersRepository ?? FakeRemindersRepository();
    final scheduler = reminderScheduler ?? FakeReminderScheduler();
    final settings = settingsRepository ?? FakeAppSettingsRepository();
    final usage = usageRepository ?? FakeUsageRepository();
    final cubit = SettingsCubit(
      getAnalysisConsent: GetAnalysisConsent(consent),
      setAnalysisConsent: SetAnalysisConsent(consent),
      getProcessingMode: GetProcessingMode(mode),
      setProcessingMode: SetProcessingMode(mode),
      getDefaultReadingSpeed: GetDefaultReadingSpeed(speed),
      setDefaultReadingSpeed: SetDefaultReadingSpeed(speed),
      getDefaultReadingVoice: GetDefaultReadingVoice(voice),
      getResumeReadingEnabled: GetResumeReadingEnabled(resume),
      setResumeReadingEnabled: SetResumeReadingEnabled(resume),
      previewDefaultVoice: PreviewDefaultVoice(
        ttsService,
        const SelectVoiceForReading(),
      ),
      getCameraPermission: GetCameraPermission(cameraPermission),
      openPermissionSettings: OpenPermissionSettings(cameraPermission),
      getNotificationPermission: GetNotificationPermission(
        notificationPermission,
      ),
      openNotificationSettings: OpenNotificationPermissionSettings(
        notificationPermission,
      ),
      getHideSensitiveNotificationDetails: GetHideSensitiveNotificationDetails(
        notificationPrivacy,
      ),
      setHideSensitiveNotificationDetails: SetHideSensitiveNotificationDetails(
        notificationPrivacy,
      ),
      deleteAllDocuments: DeleteAllDocuments(documents),
      deleteAllReminders: DeleteAllReminders(reminders, scheduler),
      deleteAllAppData: DeleteAllAppData(
        DeleteAllDocuments(documents),
        DeleteAllReminders(reminders, scheduler),
        settings,
      ),
      getDailyUsage: GetDailyUsage(usage),
      getAppVersion: GetAppVersion(
        AppEnvironment.dev(isAndroid: false, appVersion: appVersion),
      ),
    );
    addTearDown(cubit.close);
    addTearDown(ttsService.dispose);
    return cubit;
  }

  const readyDefaults = SettingsReady(
    analysisConsent: true,
    processingMode: ProcessingMode.smartAnalysis,
    defaultReadingSpeed: ReadingSpeed.normal,
    defaultReadingVoice: null,
    resumeReadingEnabled: true,
    cameraPermission: PermissionOutcome.granted,
    notificationPermission: PermissionOutcome.granted,
    hideSensitiveNotificationDetails: true,
    dailyUsage: null,
    appVersion: '1.0.0',
  );

  test('starts loading', () {
    expect(buildCubit().state, const SettingsLoading());
  });

  test('load() reads the persisted settings, defaulting to consent on and '
      'smart analysis', () async {
    final cubit = buildCubit();
    await cubit.load();

    expect(cubit.state, readyDefaults);
  });

  test('load() reflects an explicit decline', () async {
    final cubit = buildCubit(consentStore: FakeAnalysisConsentStore(false));
    await cubit.load();

    expect(cubit.state, readyDefaults.copyWith(analysisConsent: false));
  });

  test('load() reflects a persisted textOnly mode', () async {
    final cubit = buildCubit(
      modeStore: FakeProcessingModeStore(ProcessingMode.textOnly),
    );
    await cubit.load();

    expect(
      cubit.state,
      readyDefaults.copyWith(processingMode: ProcessingMode.textOnly),
    );
  });

  test('setAnalysisConsent() emits and persists', () async {
    final store = FakeAnalysisConsentStore();
    final cubit = buildCubit(consentStore: store);
    await cubit.load();

    await cubit.setAnalysisConsent(false);

    expect(cubit.state, readyDefaults.copyWith(analysisConsent: false));
    expect(await store.readConsent(), isFalse);
  });

  test('setAnalysisConsent() before load() is a no-op', () async {
    final store = FakeAnalysisConsentStore();
    final cubit = buildCubit(consentStore: store);

    await cubit.setAnalysisConsent(false);

    expect(cubit.state, const SettingsLoading());
    expect(await store.readConsent(), isNull);
  });

  test('setProcessingMode() emits and persists', () async {
    final store = FakeProcessingModeStore();
    final cubit = buildCubit(modeStore: store);
    await cubit.load();

    await cubit.setProcessingMode(ProcessingMode.textOnly);

    expect(
      cubit.state,
      readyDefaults.copyWith(processingMode: ProcessingMode.textOnly),
    );
    expect(await store.readMode(), ProcessingMode.textOnly);
  });

  test('setProcessingMode() before load() is a no-op', () async {
    final store = FakeProcessingModeStore();
    final cubit = buildCubit(modeStore: store);

    await cubit.setProcessingMode(ProcessingMode.textOnly);

    expect(cubit.state, const SettingsLoading());
    expect(await store.readMode(), isNull);
  });

  group('audio prefs (F11-T07)', () {
    test(
      'load() reflects a persisted speed, voice and resume choice',
      () async {
        const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
        final cubit = buildCubit(
          speedStore: FakeDefaultReadingSpeedStore(ReadingSpeed.faster),
          voiceStore: FakeDefaultReadingVoiceStore(voice),
          resumeStore: FakeResumeReadingEnabledStore(false),
          tts: FakeTextToSpeechService(voices: const [voice]),
        );

        await cubit.load();

        expect(
          cubit.state,
          readyDefaults.copyWith(
            defaultReadingSpeed: ReadingSpeed.faster,
            defaultReadingVoice: voice,
            resumeReadingEnabled: false,
          ),
        );
      },
    );

    test('setDefaultReadingSpeed() emits and persists', () async {
      final store = FakeDefaultReadingSpeedStore();
      final cubit = buildCubit(speedStore: store);
      await cubit.load();

      await cubit.setDefaultReadingSpeed(ReadingSpeed.slower);

      expect(
        cubit.state,
        readyDefaults.copyWith(defaultReadingSpeed: ReadingSpeed.slower),
      );
      expect(await store.readSpeed(), ReadingSpeed.slower);
    });

    test('setDefaultReadingSpeed() before load() is a no-op', () async {
      final store = FakeDefaultReadingSpeedStore();
      final cubit = buildCubit(speedStore: store);

      await cubit.setDefaultReadingSpeed(ReadingSpeed.slower);

      expect(cubit.state, const SettingsLoading());
      expect(await store.readSpeed(), isNull);
    });

    test('setResumeReadingEnabled() emits and persists', () async {
      final store = FakeResumeReadingEnabledStore();
      final cubit = buildCubit(resumeStore: store);
      await cubit.load();

      await cubit.setResumeReadingEnabled(false);

      expect(cubit.state, readyDefaults.copyWith(resumeReadingEnabled: false));
      expect(await store.readEnabled(), isFalse);
    });

    test('previewVoice() speaks the sample and reports success', () async {
      final tts = FakeTextToSpeechService();
      final cubit = buildCubit(tts: tts);
      await cubit.load();

      final played = await cubit.previewVoice(_ar);

      expect(played, isTrue);
      expect(tts.spoken, [_ar.settingsAudioPreviewSample]);
    });

    test(
      'previewVoice() reports a failure rather than swallowing it',
      () async {
        final tts = FakeTextToSpeechService(speakFails: true);
        final cubit = buildCubit(tts: tts);
        await cubit.load();

        final played = await cubit.previewVoice(_ar);

        expect(played, isFalse);
      },
    );

    test('previewVoice() before load() is a no-op', () async {
      final tts = FakeTextToSpeechService();
      final cubit = buildCubit(tts: tts);

      final played = await cubit.previewVoice(_ar);

      expect(played, isFalse);
      expect(tts.spoken, isEmpty);
    });
  });

  group('camera permission status (F11-T08)', () {
    test('load() reflects a denied camera permission', () async {
      final cubit = buildCubit(
        cameraPermissionRepo: FakeCameraPermissionRepository(
          status: PermissionOutcome.denied,
        ),
      );

      await cubit.load();

      expect(
        cubit.state,
        readyDefaults.copyWith(cameraPermission: PermissionOutcome.denied),
      );
    });

    test('load() reflects a permanently-denied camera permission', () async {
      final cubit = buildCubit(
        cameraPermissionRepo: FakeCameraPermissionRepository(
          status: PermissionOutcome.permanentlyDenied,
        ),
      );

      await cubit.load();

      expect(
        cubit.state,
        readyDefaults.copyWith(
          cameraPermission: PermissionOutcome.permanentlyDenied,
        ),
      );
    });

    test('load() falls back to denied when the read fails', () async {
      final cubit = buildCubit(
        cameraPermissionRepo: FakeCameraPermissionRepository(
          status: PermissionOutcome.granted,
          fails: true,
        ),
      );

      await cubit.load();

      expect(
        cubit.state,
        readyDefaults.copyWith(cameraPermission: PermissionOutcome.denied),
      );
    });

    test('refreshCameraPermission() updates only cameraPermission', () async {
      final repo = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
      );
      final cubit = buildCubit(cameraPermissionRepo: repo);
      await cubit.load();

      repo.status = PermissionOutcome.granted;
      await cubit.refreshCameraPermission();

      expect(
        cubit.state,
        readyDefaults.copyWith(cameraPermission: PermissionOutcome.granted),
      );
    });

    test('refreshCameraPermission() before load() is a no-op', () async {
      final cubit = buildCubit();

      await cubit.refreshCameraPermission();

      expect(cubit.state, const SettingsLoading());
    });

    test('refreshCameraPermission() falls back to denied, same as load(), '
        'when the re-check fails after a successful load()', () async {
      final repo = FakeCameraPermissionRepository(
        status: PermissionOutcome.granted,
      );
      final cubit = buildCubit(cameraPermissionRepo: repo);
      await cubit.load();
      expect(cubit.state, readyDefaults);

      repo.fails = true;
      await cubit.refreshCameraPermission();

      expect(
        cubit.state,
        readyDefaults.copyWith(cameraPermission: PermissionOutcome.denied),
      );
    });

    test('openCameraSettings() calls through to the repository', () async {
      final repo = FakeCameraPermissionRepository(
        status: PermissionOutcome.permanentlyDenied,
      );
      final cubit = buildCubit(cameraPermissionRepo: repo);
      await cubit.load();

      await cubit.openCameraSettings();

      expect(repo.openSettingsCount, 1);
    });

    test(
      'openCameraSettings() does not throw when the repository fails',
      () async {
        final repo = FakeCameraPermissionRepository(
          status: PermissionOutcome.permanentlyDenied,
          fails: true,
        );
        final cubit = buildCubit(cameraPermissionRepo: repo);
        await cubit.load();

        await cubit.openCameraSettings();

        expect(repo.openSettingsCount, 1);
      },
    );
  });

  group('notification permission status (F11-T09)', () {
    test('load() reflects a denied notification permission', () async {
      final cubit = buildCubit(
        notificationPermissionRepo: FakeNotificationPermissionRepository(
          status: PermissionOutcome.denied,
        ),
      );

      await cubit.load();

      expect(
        cubit.state,
        readyDefaults.copyWith(
          notificationPermission: PermissionOutcome.denied,
        ),
      );
    });

    test(
      'load() reflects a permanently-denied notification permission',
      () async {
        final cubit = buildCubit(
          notificationPermissionRepo: FakeNotificationPermissionRepository(
            status: PermissionOutcome.permanentlyDenied,
          ),
        );

        await cubit.load();

        expect(
          cubit.state,
          readyDefaults.copyWith(
            notificationPermission: PermissionOutcome.permanentlyDenied,
          ),
        );
      },
    );

    test('load() falls back to denied when the read fails', () async {
      final cubit = buildCubit(
        notificationPermissionRepo: FakeNotificationPermissionRepository(
          fails: true,
        ),
      );

      await cubit.load();

      expect(
        cubit.state,
        readyDefaults.copyWith(
          notificationPermission: PermissionOutcome.denied,
        ),
      );
    });

    test(
      'refreshNotificationPermission() updates only notificationPermission',
      () async {
        final repo = FakeNotificationPermissionRepository(
          status: PermissionOutcome.denied,
        );
        final cubit = buildCubit(notificationPermissionRepo: repo);
        await cubit.load();

        repo.status = PermissionOutcome.granted;
        await cubit.refreshNotificationPermission();

        expect(
          cubit.state,
          readyDefaults.copyWith(
            notificationPermission: PermissionOutcome.granted,
          ),
        );
      },
    );

    test('refreshNotificationPermission() before load() is a no-op', () async {
      final cubit = buildCubit();

      await cubit.refreshNotificationPermission();

      expect(cubit.state, const SettingsLoading());
    });

    test('refreshNotificationPermission() falls back to denied, same as '
        'load(), when the re-check fails after a successful load()', () async {
      final repo = FakeNotificationPermissionRepository();
      final cubit = buildCubit(notificationPermissionRepo: repo);
      await cubit.load();
      expect(cubit.state, readyDefaults);

      repo.fails = true;
      await cubit.refreshNotificationPermission();

      expect(
        cubit.state,
        readyDefaults.copyWith(
          notificationPermission: PermissionOutcome.denied,
        ),
      );
    });

    test(
      'openNotificationSettings() calls through to the repository',
      () async {
        final repo = FakeNotificationPermissionRepository(
          status: PermissionOutcome.permanentlyDenied,
        );
        final cubit = buildCubit(notificationPermissionRepo: repo);
        await cubit.load();

        await cubit.openNotificationSettings();

        expect(repo.openSettingsCount, 1);
      },
    );

    test(
      'openNotificationSettings() does not throw when the repository fails',
      () async {
        final repo = FakeNotificationPermissionRepository(
          status: PermissionOutcome.permanentlyDenied,
          fails: true,
        );
        final cubit = buildCubit(notificationPermissionRepo: repo);
        await cubit.load();

        await cubit.openNotificationSettings();

        expect(repo.openSettingsCount, 1);
      },
    );
  });

  group('notification-privacy toggle (F11-T10)', () {
    test('load() defaults to hidden (on)', () async {
      final cubit = buildCubit();

      await cubit.load();

      expect(cubit.state, readyDefaults);
    });

    test('load() reflects a previously revealed choice', () async {
      final cubit = buildCubit(
        notificationPrivacyStore: FakeNotificationPrivacyStore(false),
      );

      await cubit.load();

      expect(
        cubit.state,
        readyDefaults.copyWith(hideSensitiveNotificationDetails: false),
      );
    });

    test('setHideSensitiveNotificationDetails() emits and persists', () async {
      final store = FakeNotificationPrivacyStore();
      final cubit = buildCubit(notificationPrivacyStore: store);
      await cubit.load();

      await cubit.setHideSensitiveNotificationDetails(false);

      expect(
        cubit.state,
        readyDefaults.copyWith(hideSensitiveNotificationDetails: false),
      );
      expect(await store.readHideSensitiveDetails(), isFalse);
    });

    test(
      'setHideSensitiveNotificationDetails() before load() is a no-op',
      () async {
        final store = FakeNotificationPrivacyStore();
        final cubit = buildCubit(notificationPrivacyStore: store);

        await cubit.setHideSensitiveNotificationDetails(false);

        expect(cubit.state, const SettingsLoading());
        expect(await store.readHideSensitiveDetails(), isNull);
      },
    );
  });

  group('delete all documents (F11-T11)', () {
    test('deleteAllDocuments() calls through to the repository', () async {
      final repo = FakeDocumentsRepository();
      final cubit = buildCubit(documentsRepository: repo);
      await cubit.load();

      final ok = await cubit.deleteAllDocuments();

      expect(ok, isTrue);
      expect(repo.deleteAllCalled, isTrue);
    });

    test('deleteAllDocuments() answers false on failure', () async {
      final repo = FakeDocumentsRepository()
        ..deleteAllOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit(documentsRepository: repo);
      await cubit.load();

      final ok = await cubit.deleteAllDocuments();

      expect(ok, isFalse);
    });

    test('deleteAllDocuments() before load() is a no-op', () async {
      final repo = FakeDocumentsRepository();
      final cubit = buildCubit(documentsRepository: repo);

      final ok = await cubit.deleteAllDocuments();

      expect(ok, isFalse);
      expect(repo.deleteAllCalled, isFalse);
    });
  });

  group('delete all reminders (F11-T11)', () {
    test('deleteAllReminders() calls through and reconciles', () async {
      final repo = FakeRemindersRepository();
      final scheduler = FakeReminderScheduler();
      final cubit = buildCubit(
        remindersRepository: repo,
        reminderScheduler: scheduler,
      );
      await cubit.load();

      final ok = await cubit.deleteAllReminders();

      expect(ok, isTrue);
      expect(repo.deleteAllCalled, isTrue);
      expect(scheduler.reconcileCount, 1);
    });

    test('deleteAllReminders() answers false on failure', () async {
      final repo = FakeRemindersRepository()
        ..deleteAllOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit(remindersRepository: repo);
      await cubit.load();

      final ok = await cubit.deleteAllReminders();

      expect(ok, isFalse);
    });

    test('deleteAllReminders() before load() is a no-op', () async {
      final repo = FakeRemindersRepository();
      final cubit = buildCubit(remindersRepository: repo);

      final ok = await cubit.deleteAllReminders();

      expect(ok, isFalse);
      expect(repo.deleteAllCalled, isFalse);
    });
  });

  group('delete all app data (F11-T11)', () {
    test('deleteAllAppData() clears everything and reloads', () async {
      final settings = FakeAppSettingsRepository();
      final cubit = buildCubit(settingsRepository: settings);
      await cubit.load();

      final ok = await cubit.deleteAllAppData();

      expect(ok, isTrue);
      expect(settings.clearCalled, isTrue);
      // load() re-ran after the wipe, so the state is still SettingsReady —
      // not left stale from before the wipe.
      expect(cubit.state, isA<SettingsReady>());
    });

    test('deleteAllAppData() does not reload on failure', () async {
      final settings = FakeAppSettingsRepository()
        ..clearOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit(settingsRepository: settings);
      await cubit.load();
      final before = cubit.state;

      final ok = await cubit.deleteAllAppData();

      expect(ok, isFalse);
      expect(cubit.state, same(before));
    });

    test('deleteAllAppData() before load() is a no-op', () async {
      final settings = FakeAppSettingsRepository();
      final cubit = buildCubit(settingsRepository: settings);

      final ok = await cubit.deleteAllAppData();

      expect(ok, isFalse);
      expect(settings.clearCalled, isFalse);
    });
  });

  group('about section (F11-T12)', () {
    test('load() reflects nothing cached yet as a null dailyUsage', () async {
      final cubit = buildCubit();

      await cubit.load();

      expect(cubit.state, readyDefaults);
      expect((cubit.state as SettingsReady).dailyUsage, isNull);
    });

    test('load() reflects today\'s cached quota', () async {
      final usage = FakeUsageRepository(
        seed: usageWith(limit: 3, remaining: 2),
      );
      final cubit = buildCubit(usageRepository: usage);

      await cubit.load();

      expect(
        (cubit.state as SettingsReady).dailyUsage,
        usageWith(limit: 3, remaining: 2),
      );
    });

    test('load() reads the platform version', () async {
      final cubit = buildCubit(appVersion: '2.3.1');

      await cubit.load();

      expect((cubit.state as SettingsReady).appVersion, '2.3.1');
    });
  });
}
