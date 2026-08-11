import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analysis/processing_mode.dart';
import '../../../../core/analysis/usecases/get_analysis_consent.dart';
import '../../../../core/analysis/usecases/get_processing_mode.dart';
import '../../../../core/analysis/usecases/set_analysis_consent.dart';
import '../../../../core/analysis/usecases/set_processing_mode.dart';
import 'settings_state.dart';

/// Drives the settings screen (F11-T02 onward). Depends on use cases only.
final class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required GetAnalysisConsent getAnalysisConsent,
    required SetAnalysisConsent setAnalysisConsent,
    required GetProcessingMode getProcessingMode,
    required SetProcessingMode setProcessingMode,
  }) : _getAnalysisConsent = getAnalysisConsent,
       _setAnalysisConsent = setAnalysisConsent,
       _getProcessingMode = getProcessingMode,
       _setProcessingMode = setProcessingMode,
       super(const SettingsLoading());

  final GetAnalysisConsent _getAnalysisConsent;
  final SetAnalysisConsent _setAnalysisConsent;
  final GetProcessingMode _getProcessingMode;
  final SetProcessingMode _setProcessingMode;

  /// Reads every persisted setting once, on screen mount.
  Future<void> load() async {
    final analysisConsent = await _getAnalysisConsent();
    final processingMode = await _getProcessingMode();
    if (isClosed) return;
    emit(
      SettingsReady(
        analysisConsent: analysisConsent,
        processingMode: processingMode,
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
}
