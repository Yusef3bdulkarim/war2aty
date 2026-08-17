import '../../../../core/analysis/processing_mode.dart';
import '../../../../core/audio/reading_speed.dart';
import '../../../../core/audio/tts_voice.dart';
import '../../../../core/permissions/permission_service.dart';

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
    required this.availableVoices,
    required this.resumeReadingEnabled,
    required this.cameraPermission,
  });

  /// «السماح بإرسال النص للتحليل» (F11-T02).
  final bool analysisConsent;

  /// «طريقة معالجة الأوراق» (F11-T03).
  final ProcessingMode processingMode;

  /// «سرعة القراءة الافتراضية» (F11-T07).
  final ReadingSpeed defaultReadingSpeed;

  /// «صوت القراءة» (F11-T07) — `null` is «الصوت الافتراضي», the automatic
  /// script match `SelectVoiceForReading` picks with nothing overriding it.
  final TtsVoice? defaultReadingVoice;

  /// The device's installed voices, for the «صوت القراءة» picker (F11-T07) —
  /// empty on a device that reports none, or while `GetAvailableVoices`
  /// could not read them; either way the picker still offers «الصوت
  /// الافتراضي» on its own.
  final List<TtsVoice> availableVoices;

  /// «استكمال القراءة من آخر مكان» (F11-T07).
  final bool resumeReadingEnabled;

  /// «إذن الكاميرا» (F11-T08).
  final PermissionOutcome cameraPermission;

  SettingsReady copyWith({
    bool? analysisConsent,
    ProcessingMode? processingMode,
    ReadingSpeed? defaultReadingSpeed,
    TtsVoice? defaultReadingVoice,
    bool clearDefaultReadingVoice = false,
    List<TtsVoice>? availableVoices,
    bool? resumeReadingEnabled,
    PermissionOutcome? cameraPermission,
  }) => SettingsReady(
    analysisConsent: analysisConsent ?? this.analysisConsent,
    processingMode: processingMode ?? this.processingMode,
    defaultReadingSpeed: defaultReadingSpeed ?? this.defaultReadingSpeed,
    defaultReadingVoice: clearDefaultReadingVoice
        ? null
        : defaultReadingVoice ?? this.defaultReadingVoice,
    availableVoices: availableVoices ?? this.availableVoices,
    resumeReadingEnabled: resumeReadingEnabled ?? this.resumeReadingEnabled,
    cameraPermission: cameraPermission ?? this.cameraPermission,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsReady &&
          other.analysisConsent == analysisConsent &&
          other.processingMode == processingMode &&
          other.defaultReadingSpeed == defaultReadingSpeed &&
          other.defaultReadingVoice == defaultReadingVoice &&
          _listEquals(other.availableVoices, availableVoices) &&
          other.resumeReadingEnabled == resumeReadingEnabled &&
          other.cameraPermission == cameraPermission;

  @override
  int get hashCode => Object.hash(
    analysisConsent,
    processingMode,
    defaultReadingSpeed,
    defaultReadingVoice,
    Object.hashAll(availableVoices),
    resumeReadingEnabled,
    cameraPermission,
  );
}

bool _listEquals(List<TtsVoice> a, List<TtsVoice> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
