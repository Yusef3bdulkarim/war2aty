import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analysis/processing_mode.dart';
import '../../../../core/analysis/usecases/get_analysis_consent.dart';
import '../../../../core/analysis/usecases/get_processing_mode.dart';
import '../../../../core/analysis/usecases/set_analysis_consent.dart';
import '../../../../core/analysis/usecases/set_processing_mode.dart';
import '../../../../core/audio/reading_speed.dart';
import '../../../../core/audio/usecases/get_default_reading_speed.dart';
import '../../../../core/audio/usecases/get_default_reading_voice.dart';
import '../../../../core/audio/usecases/get_resume_reading_enabled.dart';
import '../../../../core/audio/usecases/preview_default_voice.dart';
import '../../../../core/audio/usecases/set_default_reading_speed.dart';
import '../../../../core/audio/usecases/set_resume_reading_enabled.dart';
import '../../../../core/documents/usecases/delete_all_documents.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/permissions/usecases/get_notification_permission.dart';
import '../../../../core/permissions/usecases/open_notification_permission_settings.dart';
import '../../../../core/reminders/usecases/delete_all_reminders.dart';
import '../../../../core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import '../../../../core/reminders/usecases/set_hide_sensitive_notification_details.dart';
import '../../../../core/settings/usecases/delete_all_app_data.dart';
import '../../../capture/domain/usecases/get_camera_permission.dart';
import '../../../capture/domain/usecases/open_permission_settings.dart';
import 'settings_state.dart';

/// Drives the settings screen (F11-T02 onward). Depends on use cases only.
final class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required GetAnalysisConsent getAnalysisConsent,
    required SetAnalysisConsent setAnalysisConsent,
    required GetProcessingMode getProcessingMode,
    required SetProcessingMode setProcessingMode,
    required GetDefaultReadingSpeed getDefaultReadingSpeed,
    required SetDefaultReadingSpeed setDefaultReadingSpeed,
    required GetDefaultReadingVoice getDefaultReadingVoice,
    required GetResumeReadingEnabled getResumeReadingEnabled,
    required SetResumeReadingEnabled setResumeReadingEnabled,
    required PreviewDefaultVoice previewDefaultVoice,
    required GetCameraPermission getCameraPermission,
    required OpenPermissionSettings openPermissionSettings,
    required GetNotificationPermission getNotificationPermission,
    required OpenNotificationPermissionSettings openNotificationSettings,
    required GetHideSensitiveNotificationDetails
    getHideSensitiveNotificationDetails,
    required SetHideSensitiveNotificationDetails
    setHideSensitiveNotificationDetails,
    required DeleteAllDocuments deleteAllDocuments,
    required DeleteAllReminders deleteAllReminders,
    required DeleteAllAppData deleteAllAppData,
  }) : _getAnalysisConsent = getAnalysisConsent,
       _setAnalysisConsent = setAnalysisConsent,
       _getProcessingMode = getProcessingMode,
       _setProcessingMode = setProcessingMode,
       _getDefaultReadingSpeed = getDefaultReadingSpeed,
       _setDefaultReadingSpeed = setDefaultReadingSpeed,
       _getDefaultReadingVoice = getDefaultReadingVoice,
       _getResumeReadingEnabled = getResumeReadingEnabled,
       _setResumeReadingEnabled = setResumeReadingEnabled,
       _previewDefaultVoice = previewDefaultVoice,
       _getCameraPermission = getCameraPermission,
       _openPermissionSettings = openPermissionSettings,
       _getNotificationPermission = getNotificationPermission,
       _openNotificationSettings = openNotificationSettings,
       _getHideSensitiveNotificationDetails =
           getHideSensitiveNotificationDetails,
       _setHideSensitiveNotificationDetails =
           setHideSensitiveNotificationDetails,
       _deleteAllDocuments = deleteAllDocuments,
       _deleteAllReminders = deleteAllReminders,
       _deleteAllAppData = deleteAllAppData,
       super(const SettingsLoading());

  final GetAnalysisConsent _getAnalysisConsent;
  final SetAnalysisConsent _setAnalysisConsent;
  final GetProcessingMode _getProcessingMode;
  final SetProcessingMode _setProcessingMode;
  final GetDefaultReadingSpeed _getDefaultReadingSpeed;
  final SetDefaultReadingSpeed _setDefaultReadingSpeed;
  final GetDefaultReadingVoice _getDefaultReadingVoice;
  final GetResumeReadingEnabled _getResumeReadingEnabled;
  final SetResumeReadingEnabled _setResumeReadingEnabled;
  final PreviewDefaultVoice _previewDefaultVoice;
  final GetCameraPermission _getCameraPermission;
  final OpenPermissionSettings _openPermissionSettings;
  final GetNotificationPermission _getNotificationPermission;
  final OpenNotificationPermissionSettings _openNotificationSettings;
  final GetHideSensitiveNotificationDetails
  _getHideSensitiveNotificationDetails;
  final SetHideSensitiveNotificationDetails
  _setHideSensitiveNotificationDetails;
  final DeleteAllDocuments _deleteAllDocuments;
  final DeleteAllReminders _deleteAllReminders;
  final DeleteAllAppData _deleteAllAppData;

  /// Reads every persisted setting once, on screen mount.
  ///
  /// Every read below is kicked off together rather than one `await` after
  /// another — they don't depend on each other, so waiting on them
  /// sequentially only added up their latencies for no reason (the settings
  /// screen visibly stalling on open, F11 perceived-hang bug).
  Future<void> load() async {
    final analysisConsentFuture = _getAnalysisConsent();
    final processingModeFuture = _getProcessingMode();
    final defaultReadingSpeedFuture = _getDefaultReadingSpeed();
    final defaultReadingVoiceFuture = _getDefaultReadingVoice();
    final resumeReadingEnabledFuture = _getResumeReadingEnabled();
    final cameraPermissionFuture = _getCameraPermission();
    final notificationPermissionFuture = _getNotificationPermission();
    final hideSensitiveNotificationDetailsFuture =
        _getHideSensitiveNotificationDetails();

    final analysisConsent = await analysisConsentFuture;
    final processingMode = await processingModeFuture;
    final defaultReadingSpeed = await defaultReadingSpeedFuture;
    final defaultReadingVoice = await defaultReadingVoiceFuture;
    final resumeReadingEnabled = await resumeReadingEnabledFuture;
    final cameraPermission =
        (await cameraPermissionFuture).valueOrNull ?? PermissionOutcome.denied;
    final notificationPermission =
        (await notificationPermissionFuture).valueOrNull ??
        PermissionOutcome.denied;
    final hideSensitiveNotificationDetails =
        await hideSensitiveNotificationDetailsFuture;
    if (isClosed) return;
    emit(
      SettingsReady(
        analysisConsent: analysisConsent,
        processingMode: processingMode,
        defaultReadingSpeed: defaultReadingSpeed,
        defaultReadingVoice: defaultReadingVoice,
        resumeReadingEnabled: resumeReadingEnabled,
        cameraPermission: cameraPermission,
        notificationPermission: notificationPermission,
        hideSensitiveNotificationDetails: hideSensitiveNotificationDetails,
      ),
    );
  }

  /// Toggles «السماح بإرسال النص للتحليل» (F11-T02).
  ///
  /// Emits before the write settles (the store cannot meaningfully fail in a
  /// way the user can act on — same reasoning `LocaleCubit.setLanguage`
  /// applies to a persisted choice) so the switch responds immediately.
  Future<void> setAnalysisConsent(bool consent) async {
    final current = state;
    if (current is! SettingsReady) return;
    emit(current.copyWith(analysisConsent: consent));
    await _setAnalysisConsent(consent);
  }

  /// Selects «طريقة معالجة الأوراق» (F11-T03).
  ///
  /// Same emit-first pattern as [setAnalysisConsent].
  Future<void> setProcessingMode(ProcessingMode mode) async {
    final current = state;
    if (current is! SettingsReady) return;
    emit(current.copyWith(processingMode: mode));
    await _setProcessingMode(mode);
  }

  /// Picks «سرعة القراءة الافتراضية» (F11-T07).
  ///
  /// Same emit-first pattern as [setAnalysisConsent].
  Future<void> setDefaultReadingSpeed(ReadingSpeed speed) async {
    final current = state;
    if (current is! SettingsReady) return;
    emit(current.copyWith(defaultReadingSpeed: speed));
    await _setDefaultReadingSpeed(speed);
  }

  /// Toggles «استكمال القراءة من آخر مكان» (F11-T07).
  ///
  /// Same emit-first pattern as [setAnalysisConsent].
  Future<void> setResumeReadingEnabled(bool enabled) async {
    final current = state;
    if (current is! SettingsReady) return;
    emit(current.copyWith(resumeReadingEnabled: enabled));
    await _setResumeReadingEnabled(enabled);
  }

  /// Plays «تجربة الصوت» (F11-T07) using whichever speed/voice are currently
  /// selected on screen — not necessarily saved yet, so the user hears what
  /// they are about to confirm. Answers whether it played, for the screen to
  /// surface a failure rather than leaving a silent tap unexplained (no
  /// silent failures, CLAUDE.md §A3).
  Future<bool> previewVoice(AppStrings strings) async {
    final current = state;
    if (current is! SettingsReady) return false;
    final outcome = await _previewDefaultVoice(
      sampleText: strings.settingsAudioPreviewSample,
      speed: current.defaultReadingSpeed,
      voice: current.defaultReadingVoice,
    );
    return outcome.isOk;
  }

  /// Re-reads «إذن الكاميرا» without prompting (F11-T08) — call this on app
  /// resume, since the OS settings app is a round trip out of the process
  /// and only a re-check on return notices what changed there.
  ///
  /// Falls back to [PermissionOutcome.denied] on a failed read, the same
  /// policy [load] already applies — a transient failure here is treated
  /// exactly like a transient failure during the initial load rather than
  /// keeping the last known-good value.
  Future<void> refreshCameraPermission() async {
    final current = state;
    if (current is! SettingsReady) return;
    final cameraPermission =
        (await _getCameraPermission()).valueOrNull ?? PermissionOutcome.denied;
    if (isClosed) return;
    emit(current.copyWith(cameraPermission: cameraPermission));
  }

  /// «فتح إعدادات الكاميرا» (F11-T08).
  ///
  /// No result surfaces here — [refreshCameraPermission] on app resume is
  /// what reflects whatever the user changed there, the same contract
  /// `CameraPermissionCubit.allow()` already uses for this same use case.
  Future<void> openCameraSettings() => _openPermissionSettings().then((_) {});

  /// Re-reads «إذن الإشعارات» without prompting (F11-T09) — same reasoning
  /// and same denied-on-failure fallback as [refreshCameraPermission].
  Future<void> refreshNotificationPermission() async {
    final current = state;
    if (current is! SettingsReady) return;
    final notificationPermission =
        (await _getNotificationPermission()).valueOrNull ??
        PermissionOutcome.denied;
    if (isClosed) return;
    emit(current.copyWith(notificationPermission: notificationPermission));
  }

  /// «فتح إعدادات الإشعارات» (F11-T09) — same contract as
  /// [openCameraSettings].
  Future<void> openNotificationSettings() =>
      _openNotificationSettings().then((_) {});

  /// Toggles «إخفاء التفاصيل الحساسة من شاشة القفل» (F11-T10) — persists the
  /// same setting `FlutterLocalNotificationsReminderScheduler` already reads
  /// on every reminder fire (F09-T14).
  ///
  /// Same emit-first pattern as [setAnalysisConsent].
  Future<void> setHideSensitiveNotificationDetails(bool hide) async {
    final current = state;
    if (current is! SettingsReady) return;
    emit(current.copyWith(hideSensitiveNotificationDetails: hide));
    await _setHideSensitiveNotificationDetails(hide);
  }

  /// «حذف كل المستندات» (F11-T11) — after the user confirms on the sheet.
  ///
  /// Answers whether it succeeded, for the screen to show a snackbar rather
  /// than leave a permanent delete unexplained (no silent failures, CLAUDE.md
  /// §A3). No-ops before [load], the same guard every setter uses.
  Future<bool> deleteAllDocuments() async {
    if (state is! SettingsReady) return false;
    return (await _deleteAllDocuments()).isOk;
  }

  /// «حذف كل التذكيرات» (F11-T11). Same contract as [deleteAllDocuments].
  Future<bool> deleteAllReminders() async {
    if (state is! SettingsReady) return false;
    return (await _deleteAllReminders()).isOk;
  }

  /// «حذف كل بيانات التطبيق» (F11-T11). Same contract as [deleteAllDocuments].
  ///
  /// On success, every setting this screen owns has just reverted to its
  /// default — [load] re-reads them so the screen reflects that immediately
  /// rather than showing stale values until the next launch.
  Future<bool> deleteAllAppData() async {
    if (state is! SettingsReady) return false;
    final result = await _deleteAllAppData();
    if (result.isOk) await load();
    return result.isOk;
  }
}
