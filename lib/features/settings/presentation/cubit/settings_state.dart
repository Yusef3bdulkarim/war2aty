import '../../../../core/analysis/processing_mode.dart';
import '../../../../core/audio/reading_speed.dart';
import '../../../../core/audio/tts_voice.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/usage/daily_usage.dart';

/// States of the settings screen (F11-T02 onward).
sealed class SettingsState {
  const SettingsState();
}

/// The persisted settings have not been read yet.
final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// Every setting this screen currently exposes, read and ready to draw.
///
/// One flat state for the whole screen rather than one per section: every
/// field here is a single persisted value with no loading/error shape of its
/// own (the same reasoning `HomeState` composing usage/documents/reminders
/// does not apply — those are streams that can independently fail; these are
/// plain settings reads that either succeed or keep the section's own
/// previous value).
final class SettingsReady extends SettingsState {
  const SettingsReady({
    required this.analysisConsent,
    required this.processingMode,
    required this.defaultReadingSpeed,
    required this.defaultReadingVoice,
    required this.resumeReadingEnabled,
    required this.cameraPermission,
    required this.notificationPermission,
    required this.hideSensitiveNotificationDetails,
    required this.dailyUsage,
    required this.appVersion,
  });

  /// «السماح بإرسال النص للتحليل» (F11-T02).
  final bool analysisConsent;

  /// «طريقة معالجة الأوراق» (F11-T03).
  final ProcessingMode processingMode;

  /// «سرعة القراءة الافتراضية» (F11-T07).
  final ReadingSpeed defaultReadingSpeed;

  /// «صوت القراءة» (F11-T07) — `null` is «الصوت الافتراضي», the automatic
  /// script match `SelectVoiceForReading` picks with nothing overriding it.
  ///
  /// The voice picker was removed from the Settings UI (most device voices
  /// are unsuitable for Arabic) but the stored preference is still loaded and
  /// used by the audio reader and the preview button.
  final TtsVoice? defaultReadingVoice;

  /// «استكمال القراءة من آخر مكان» (F11-T07).
  final bool resumeReadingEnabled;

  /// «إذن الكاميرا» (F11-T08).
  final PermissionOutcome cameraPermission;

  /// «إذن الإشعارات» (F11-T09).
  final PermissionOutcome notificationPermission;

  /// «إخفاء التفاصيل الحساسة من شاشة القفل» (F11-T10).
  final bool hideSensitiveNotificationDetails;

  /// Today's cached analysis quota, for the «حدود الاستخدام» row (F11-T12).
  /// `null` when nothing has been cached yet — a real state, not an error.
  final DailyUsage? dailyUsage;

  /// «الإصدار» line (F11-T12), read from the platform bundle at launch.
  final String appVersion;

  SettingsReady copyWith({
    bool? analysisConsent,
    ProcessingMode? processingMode,
    ReadingSpeed? defaultReadingSpeed,
    TtsVoice? defaultReadingVoice,
    bool clearDefaultReadingVoice = false,
    bool? resumeReadingEnabled,
    PermissionOutcome? cameraPermission,
    PermissionOutcome? notificationPermission,
    bool? hideSensitiveNotificationDetails,
    DailyUsage? dailyUsage,
    bool clearDailyUsage = false,
    String? appVersion,
  }) => SettingsReady(
    analysisConsent: analysisConsent ?? this.analysisConsent,
    processingMode: processingMode ?? this.processingMode,
    defaultReadingSpeed: defaultReadingSpeed ?? this.defaultReadingSpeed,
    defaultReadingVoice: clearDefaultReadingVoice
        ? null
        : defaultReadingVoice ?? this.defaultReadingVoice,
    resumeReadingEnabled: resumeReadingEnabled ?? this.resumeReadingEnabled,
    cameraPermission: cameraPermission ?? this.cameraPermission,
    notificationPermission:
        notificationPermission ?? this.notificationPermission,
    hideSensitiveNotificationDetails:
        hideSensitiveNotificationDetails ??
        this.hideSensitiveNotificationDetails,
    dailyUsage: clearDailyUsage ? null : dailyUsage ?? this.dailyUsage,
    appVersion: appVersion ?? this.appVersion,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsReady &&
          other.analysisConsent == analysisConsent &&
          other.processingMode == processingMode &&
          other.defaultReadingSpeed == defaultReadingSpeed &&
          other.defaultReadingVoice == defaultReadingVoice &&
          other.resumeReadingEnabled == resumeReadingEnabled &&
          other.cameraPermission == cameraPermission &&
          other.notificationPermission == notificationPermission &&
          other.hideSensitiveNotificationDetails ==
              hideSensitiveNotificationDetails &&
          other.dailyUsage == dailyUsage &&
          other.appVersion == appVersion;

  @override
  int get hashCode => Object.hash(
    analysisConsent,
    processingMode,
    defaultReadingSpeed,
    defaultReadingVoice,
    resumeReadingEnabled,
    cameraPermission,
    notificationPermission,
    hideSensitiveNotificationDetails,
    dailyUsage,
    appVersion,
  );
}
