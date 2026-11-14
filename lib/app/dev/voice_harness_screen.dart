import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../core/voice/usecases/speak_fixed_line.dart';
import '../../core/voice/voice_line.dart';
import '../../core/voice/voice_playback_cubit.dart';
import '../../core/voice/voice_playback_state.dart';
import '../../features/voice/domain/entities/voice_segment.dart';
import '../di/service_locator.dart';

/// A **development-only** harness for F37's voice spine (F37-T21).
///
/// ## Why this exists at all
///
/// F37's scope fence says it builds no screen: the spine ends at an injectable
/// `VoicePlaybackCubit`, and F39/F40/F41 are what put it in a tree. That left
/// the one part of the feature with **no unit test by construction** — Kotlin's
/// `AudioTrack`, `MediaCodec` and Android's audio focus — unrunnable on a real
/// phone until two features later, at which point a failure would be ambiguous
/// between the native layer and a brand-new result screen.
///
/// The owner chose to open the fence deliberately rather than defer the device
/// pass (T21's note records the three options). This screen is that hole, kept
/// as small as it can be:
///
/// - It is reachable **only when `AppEnvironment.isDev`** — the route is not
///   registered otherwise, so in a release build the path does not exist.
///   `voice_harness_guard_test` asserts that.
/// - It imports no product screen and nothing imports it.
/// - It is deleted with F40's wiring, which replaces it with the real thing.
///
/// ## What it is for
///
/// Driving `docs/features/F37-device-checklist.md` on the RMX2001. Every
/// control maps to a row there, and the state is printed raw — `canSeek`,
/// `canPause`, `isSpeaking`, the engine, the position — because the checklist
/// asks about exactly those, and a pretty UI would hide the thing being
/// tested.
///
/// The paper below is **invented**, so no real document is ever sent to the
/// service from here.
class VoiceHarnessScreen extends StatelessWidget {
  const VoiceHarnessScreen({super.key});

  /// A canned explanation, shaped the way F38 will hand one over: plain
  /// segments, one per result card, in Egyptian Arabic.
  static const List<VoiceSegment> _paper = [
    VoiceSegment(
      id: 'explain',
      text:
          'دي ورقة من شركة الكهرباء بتقولك إن فاتورة شهر نوفمبر طلعت، '
          'والمبلغ المطلوب مية وخمسة وتمانين جنيه.',
    ),
    VoiceSegment(
      id: 'todo',
      text:
          'ادفع الفاتورة من أي ماكينة دفع أو من فرع الشركة، '
          'وخد معاك رقم العداد المكتوب في الورقة.',
    ),
    VoiceSegment(id: 'date', text: 'آخر ميعاد للدفع يوم عشرين نوفمبر.'),
    VoiceSegment(
      id: 'caution',
      text: 'لو مدفعتش قبل الميعاد، ممكن يقطعوا الكهرباء ويضيفوا غرامة تأخير.',
    ),
  ];

  /// The id the reading is stored under. Fixed, so a replay after a restart
  /// finds the file the previous run saved — which is checklist row D1.
  static const String _audioId = 'dev-harness-paper';

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VoicePlaybackCubit>(
      create: (_) => getIt<VoicePlaybackCubit>(),
      child: const _VoiceHarnessBody(),
    );
  }
}

class _VoiceHarnessBody extends StatelessWidget {
  const _VoiceHarnessBody();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Voice harness (dev)'),
        backgroundColor: colors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _StateCard(),
            SizedBox(height: 16),
            _ReadControls(),
            SizedBox(height: 16),
            _FixedLines(),
          ],
        ),
      ),
    );
  }
}

/// The state, printed rather than rendered.
///
/// The checklist asks whether seek is refused while streaming, whether the
/// device tier declares it cannot pause, and where the position has reached.
/// All three are answered by the state object, so the state object is what is
/// shown.
class _StateCard extends StatelessWidget {
  const _StateCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoicePlaybackCubit, VoicePlaybackState>(
      builder: (context, state) {
        final lines = <String>[
          'state      ${state.runtimeType}',
          'isSpeaking ${state.isSpeaking}',
          'canPause   ${state.canPause}',
          'canSeek    ${state.canSeek}',
          ...switch (state) {
            VoicePlaybackStreaming(
              :final engine,
              :final position,
              :final segmentId,
              :final isPaused,
            ) =>
              [
                'engine     ${engine.name}',
                'position   ${position.inMilliseconds} ms',
                'segment    ${segmentId ?? '—'}',
                'paused     $isPaused',
              ],
            VoicePlaybackReadFinished(:final outcome, :final canReplay) => [
              'engine     ${outcome.engine.name}',
              'verified   ${outcome.verified}',
              'audioSaved ${outcome.audioSaved}',
              'canReplay  $canReplay',
            ],
            VoicePlaybackFile(
              :final position,
              :final duration,
              :final segmentId,
              :final isPaused,
            ) =>
              [
                'position   ${position.inMilliseconds} ms',
                'duration   ${duration.inMilliseconds} ms',
                'segment    ${segmentId ?? '—'}',
                'paused     $isPaused',
              ],
            VoicePlaybackFailed(:final failure) => [
              'failure    ${failure.runtimeType}',
            ],
            _ => const <String>[],
          },
        ];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadControls extends StatelessWidget {
  const _ReadControls();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoicePlaybackCubit, VoicePlaybackState>(
      builder: (context, state) {
        final cubit = context.read<VoicePlaybackCubit>();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () => cubit.readAloud(
                segments: VoiceHarnessScreen._paper,
                audioId: VoiceHarnessScreen._audioId,
              ),
              child: const Text('Read (A, B, C)'),
            ),
            FilledButton.tonal(
              onPressed: cubit.replay,
              child: const Text('Replay (D)'),
            ),
            OutlinedButton(
              // Offered unconditionally on purpose: checklist row C2 asks
              // what happens when pause is NOT available, and a disabled
              // button would hide the cubit's own refusal.
              onPressed: cubit.pause,
              child: Text('Pause${state.canPause ? '' : ' (refused)'}'),
            ),
            OutlinedButton(
              onPressed: cubit.resume,
              child: const Text('Resume'),
            ),
            OutlinedButton(
              // Row D3: seeking must be refused while the audio is still
              // streaming, so the control has to be reachable in that phase.
              onPressed: () => cubit.seek(const Duration(seconds: 10)),
              child: Text('Seek 10s${state.canSeek ? '' : ' (refused)'}'),
            ),
            OutlinedButton(
              onPressed: () => cubit.seekToSegment('date'),
              child: const Text('Jump to «date»'),
            ),
            OutlinedButton(
              onPressed: cubit.stop,
              child: const Text('Stop (B4)'),
            ),
          ],
        );
      },
    );
  }
}

/// All twelve bundled lines, one button each — checklist group F.
class _FixedLines extends StatelessWidget {
  const _FixedLines();

  @override
  Widget build(BuildContext context) {
    final speak = getIt<SpeakFixedLine>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fixed lines (F)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final line in VoiceLine.values)
              OutlinedButton(
                onPressed: () => speak(line),
                child: Text(line.id),
              ),
          ],
        ),
      ],
    );
  }
}
