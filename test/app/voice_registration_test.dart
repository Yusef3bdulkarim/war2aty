import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/core/env/app_environment.dart';
import 'package:war2aty/core/voice/fixed_line_player.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/features/voice/data/datasources/edge_function_live_token_data_source.dart';
import 'package:war2aty/features/voice/domain/services/audio_encoder.dart';
import 'package:war2aty/features/voice/domain/services/device_voice_reader.dart';
import 'package:war2aty/features/voice/domain/services/live_voice_session.dart';
import 'package:war2aty/features/voice/domain/services/pcm_audio_sink.dart';
import 'package:war2aty/features/voice/domain/services/saved_audio_player.dart';
import 'package:war2aty/features/voice/domain/usecases/align_segments_to_audio.dart';
import 'package:war2aty/features/voice/domain/usecases/build_voice_turn_text.dart';
import 'package:war2aty/features/voice/domain/usecases/normalise_arabic_for_diff.dart';
import 'package:war2aty/features/voice/domain/usecases/read_paper_aloud.dart';
import 'package:war2aty/features/voice/domain/usecases/replay_saved_audio.dart';
import 'package:war2aty/features/voice/domain/usecases/verify_verbatim_read.dart';

import '../support/fakes.dart';

/// F37-T21 · `_registerVoice` actually resolves.
///
/// A `get_it` registration is a closure. It compiles whatever it holds, so a
/// module can be wrong in three ways that nothing else in the suite would
/// notice: a dependency that was never registered, an interface bound to the
/// wrong implementation, and — the one that matters most here — a service
/// registered as a factory when the design needs exactly one instance of it.
///
/// Nothing in `lib/` resolves any of this yet: F37 ends at an injectable spine
/// and F39/F40/F41 are what build it. So until those land, this test *is* the
/// only consumer, and without it the whole module is unexercised code.
///
/// The platform-bound registrations are asserted as **registered** rather than
/// resolved: building `JustAudioFixedLinePlayer` or the `flutter_tts` queue
/// instantiates a plugin, which a unit test has no platform for. What that
/// cannot catch is caught where it belongs — T21's device checklist.
void main() {
  setUp(() async {
    await getIt.reset();
    // An unconfigured dev environment: no Supabase to reach, which is exactly
    // what we want. Every voice registration below is built from local objects
    // or from the shared Dio, and the Dio is registered even when the build has
    // nowhere to point.
    await configureDependencies(
      AppEnvironment.dev(),
      database: memoryDatabase(),
    );
  });

  tearDown(getIt.reset);

  group('the pure registrations resolve', () {
    test('the diff and alignment use cases', () {
      expect(getIt<NormaliseArabicForDiff>(), isA<NormaliseArabicForDiff>());
      expect(getIt<BuildVoiceTurnText>(), isA<BuildVoiceTurnText>());
      expect(getIt<VerifyVerbatimRead>(), isA<VerifyVerbatimRead>());
      expect(getIt<AlignSegmentsToAudio>(), isA<AlignSegmentsToAudio>());
    });

    test('the live token datasource', () {
      // Resolves the shared Dio under it, so a module registered before
      // `_registerNetwork` would fail here.
      expect(getIt<LiveTokenDataSource>(), isA<LiveTokenDataSource>());
    });

    test('a live session, and a different one each time', () {
      final first = getIt<LiveVoiceSession>();
      final second = getIt<LiveVoiceSession>();

      expect(first, isA<LiveVoiceSession>());
      // Live sessions are single-use: the ladder's retry asks for a second
      // one mid-read, and a singleton would hand it the spent first.
      expect(identical(first, second), isFalse);
    });
  });

  group('the platform-bound registrations are registered', () {
    test('the sink and the encoder are the SAME instance', () {
      // Two faces of one `AudioTrack` + `MediaCodec` pair behind the channel.
      // Two instances would open two tracks that fight for audio focus, and
      // the bug would appear only on a device — the reason this is asserted
      // here and not left to the checklist.
      expect(getIt<PcmAudioSink>(), same(getIt<AudioEncoder>()));
    });

    test('the device reader, the saved player and the fixed-line player', () {
      // `DeviceVoiceReader` must be a singleton — it subscribes to
      // `ReadingQueue.events` for its whole life, so a factory would add a
      // listener per resolution and each instance would read the others'
      // completions as its own reading finishing. That cannot be asserted
      // here: `get_it` exposes no "is this a singleton" query, and resolving
      // it twice to compare identity builds `flutter_tts`. It is pinned by
      // the comment on the registration and by the device checklist.
      expect(getIt.isRegistered<DeviceVoiceReader>(), isTrue);
      expect(getIt.isRegistered<SavedAudioPlayer>(), isTrue);
      expect(getIt.isRegistered<FixedLinePlayer>(), isTrue);
    });
  });

  group('the use cases above the services', () {
    test('ReadPaperAloud and ReplaySavedAudio are registered', () {
      // Not resolved: both pull the platform-bound services in. What the
      // registration being present proves is that every *named* argument of
      // `ReadPaperAloud` has a type registered to satisfy it — a missing one
      // is a compile error in `_registerVoice`, not a runtime surprise.
      expect(getIt.isRegistered<ReadPaperAloud>(), isTrue);
      expect(getIt.isRegistered<ReplaySavedAudio>(), isTrue);
    });

    test('SpeakFixedLine and VoicePlaybackCubit are registered', () {
      expect(getIt.isRegistered<SpeakFixedLine>(), isTrue);
      expect(getIt.isRegistered<VoicePlaybackCubit>(), isTrue);
    });
  });
}
