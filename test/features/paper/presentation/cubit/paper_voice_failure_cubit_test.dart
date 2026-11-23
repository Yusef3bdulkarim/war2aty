import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/usecases/open_system_tts_settings.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_line.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_voice_failure_cubit.dart';

import '../../../../support/fakes.dart';

void main() {
  late FakeFixedLinePlayer player;
  late FakeSystemTtsSettings ttsSettings;
  late FakeTextToSpeechService tts;
  late PaperVoiceFailureCubit cubit;

  setUp(() {
    player = FakeFixedLinePlayer();
    ttsSettings = FakeSystemTtsSettings();
    tts = FakeTextToSpeechService();
    cubit = PaperVoiceFailureCubit(
      SpeakFixedLine(player),
      OpenSystemTtsSettings(ttsSettings, tts),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('speaks no_arabic_voice for a NoArabicVoiceFailure', () async {
    await cubit.speakFor(const NoArabicVoiceFailure());

    expect(player.played, [VoiceLine.noArabicVoice.assetPath]);
  });

  test('speaks voice_failed for every other failure', () async {
    await cubit.speakFor(const TtsFailure());

    expect(player.played, [VoiceLine.voiceFailed.assetPath]);
  });

  test('says whether the system settings screen can be opened', () async {
    ttsSettings.available = true;
    expect(await cubit.canOpenSystemTtsSettings(), isTrue);

    ttsSettings.available = false;
    expect(await cubit.canOpenSystemTtsSettings(), isFalse);
  });

  test('opens the system settings and forgets the cached voices', () async {
    final opened = await cubit.openSystemTtsSettings();

    expect(opened, isTrue);
    expect(ttsSettings.openCount, 1);
    expect(tts.forgetVoicesCount, 1);
  });

  test('a failed open is reported', () async {
    ttsSettings.opensSuccessfully = false;

    expect(await cubit.openSystemTtsSettings(), isFalse);
  });

  test('stops the line on close', () async {
    await cubit.speakFor(const TtsFailure());

    await cubit.close();

    expect(player.stopCount, 1);
  });
}
