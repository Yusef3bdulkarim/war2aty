import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/usecases/open_system_tts_settings.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/voice/usecases/speak_fixed_line.dart';
import '../../../../core/voice/voice_line.dart';
import 'paper_voice_failure_state.dart';

final class PaperVoiceFailureCubit extends Cubit<PaperVoiceFailureState> {
  PaperVoiceFailureCubit(this._speakFixedLine, this._openSystemTtsSettings)
    : super(const PaperVoiceFailureReady());

  final SpeakFixedLine _speakFixedLine;
  final OpenSystemTtsSettings _openSystemTtsSettings;

  Future<void> speakFor(AppFailure failure) async {
    await _speakFixedLine(
      failure is NoArabicVoiceFailure
          ? VoiceLine.noArabicVoice
          : VoiceLine.voiceFailed,
    );
  }

  Future<bool> canOpenSystemTtsSettings() =>
      _openSystemTtsSettings.isAvailable();

  Future<bool> openSystemTtsSettings() => _openSystemTtsSettings();

  @override
  Future<void> close() async {
    await _speakFixedLine.stop();
    return super.close();
  }
}
