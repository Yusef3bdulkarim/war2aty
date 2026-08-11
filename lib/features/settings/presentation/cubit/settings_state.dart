import '../../../../core/analysis/processing_mode.dart';

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
  });

  /// «السماح بإرسال النص للتحليل» (F11-T02).
  final bool analysisConsent;

  /// «طريقة معالجة الأوراق» (F11-T03).
  final ProcessingMode processingMode;

  SettingsReady copyWith({
    bool? analysisConsent,
    ProcessingMode? processingMode,
  }) => SettingsReady(
    analysisConsent: analysisConsent ?? this.analysisConsent,
    processingMode: processingMode ?? this.processingMode,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsReady &&
          other.analysisConsent == analysisConsent &&
          other.processingMode == processingMode;

  @override
  int get hashCode => Object.hash(analysisConsent, processingMode);
}
