import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/get_processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/set_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/set_processing_mode.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_available_voices.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/audio/usecases/get_resume_reading_enabled.dart';
import 'package:war2aty/core/audio/usecases/preview_default_voice.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_voice.dart';
import 'package:war2aty/core/audio/usecases/set_resume_reading_enabled.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
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
  }) {
    final consent = consentStore ?? FakeAnalysisConsentStore();
    final mode = modeStore ?? FakeProcessingModeStore();
    final speed = speedStore ?? FakeDefaultReadingSpeedStore();
    final voice = voiceStore ?? FakeDefaultReadingVoiceStore();
    final resume = resumeStore ?? FakeResumeReadingEnabledStore();
    final ttsService = tts ?? FakeTextToSpeechService();
    final cubit = SettingsCubit(
      getAnalysisConsent: GetAnalysisConsent(consent),
      setAnalysisConsent: SetAnalysisConsent(consent),
      getProcessingMode: GetProcessingMode(mode),
      setProcessingMode: SetProcessingMode(mode),
      getDefaultReadingSpeed: GetDefaultReadingSpeed(speed),
      setDefaultReadingSpeed: SetDefaultReadingSpeed(speed),
      getDefaultReadingVoice: GetDefaultReadingVoice(voice),
      setDefaultReadingVoice: SetDefaultReadingVoice(voice),
      getResumeReadingEnabled: GetResumeReadingEnabled(resume),
      setResumeReadingEnabled: SetResumeReadingEnabled(resume),
      getAvailableVoices: GetAvailableVoices(ttsService),
      previewDefaultVoice: PreviewDefaultVoice(
        ttsService,
        const SelectVoiceForReading(),
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
    availableVoices: [],
    resumeReadingEnabled: true,
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
            availableVoices: const [voice],
            resumeReadingEnabled: false,
          ),
        );
      },
    );

    test('load() offers an empty voice list when getVoices fails', () async {
      final cubit = buildCubit(
        tts: FakeTextToSpeechService(getVoicesFails: true),
      );

      await cubit.load();

      expect(cubit.state, readyDefaults);
    });

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

    test(
      'setDefaultReadingVoice() emits and persists an explicit voice',
      () async {
        const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
        final store = FakeDefaultReadingVoiceStore();
        final cubit = buildCubit(voiceStore: store);
        await cubit.load();

        await cubit.setDefaultReadingVoice(voice);

        expect(cubit.state, readyDefaults.copyWith(defaultReadingVoice: voice));
        expect(await store.readVoice(), voice);
      },
    );

    test(
      'setDefaultReadingVoice(null) resets back to «الصوت الافتراضي»',
      () async {
        const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
        final store = FakeDefaultReadingVoiceStore(voice);
        final cubit = buildCubit(voiceStore: store);
        await cubit.load();

        await cubit.setDefaultReadingVoice(null);

        // Back to the untouched defaults — `defaultReadingVoice` is null again.
        expect(cubit.state, readyDefaults);
        expect(await store.readVoice(), isNull);
      },
    );

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
}
