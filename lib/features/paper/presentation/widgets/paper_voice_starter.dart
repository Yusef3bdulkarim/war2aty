import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/voice/voice_playback_cubit.dart';
import '../../../../core/voice/voice_playback_state.dart';
import '../../../../core/widgets/action_prompt_sheet.dart';
import '../cubit/paper_screen_cubit.dart';
import '../cubit/paper_screen_state.dart';
import '../cubit/paper_voice_failure_cubit.dart';
import '../models/paper_voice_start.dart';

class PaperVoiceStarter extends StatefulWidget {
  const PaperVoiceStarter({
    required this.fresh,
    required this.child,
    super.key,
  });

  final bool fresh;
  final Widget child;

  @override
  State<PaperVoiceStarter> createState() => _PaperVoiceStarterState();
}

class _PaperVoiceStarterState extends State<PaperVoiceStarter> {
  var _started = false;

  @override
  void initState() {
    super.initState();
    _startFrom(context.read<PaperScreenCubit>().state);
  }

  void _startFrom(PaperScreenState state) {
    if (_started || state is! PaperScreenReady) return;
    _started = true;

    final voice = context.read<VoicePlaybackCubit>();
    switch (PaperVoiceStart.of(state.paper, fresh: widget.fresh)) {
      case ReadPaperAloudFromStart(:final audioId, :final segments):
        unawaited(voice.readAloud(segments: segments, audioId: audioId));
      case ReplaySavedReading(:final audioId, :final spans):
        unawaited(voice.replay(audioId: audioId, spans: spans));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PaperScreenCubit, PaperScreenState>(
          listener: (_, state) => _startFrom(state),
        ),
        BlocListener<VoicePlaybackCubit, VoicePlaybackState>(
          listenWhen: (_, current) => current is VoicePlaybackReadFinished,
          listener: (context, state) {
            if (state is! VoicePlaybackReadFinished) return;
            unawaited(
              context.read<PaperScreenCubit>().recordReading(state.outcome),
            );
          },
        ),
        BlocListener<VoicePlaybackCubit, VoicePlaybackState>(
          listenWhen: (_, current) => current is VoicePlaybackFailed,
          listener: (context, state) {
            if (state is! VoicePlaybackFailed) return;
            final failureCubit = context.read<PaperVoiceFailureCubit>();
            unawaited(failureCubit.speakFor(state.failure));
            if (state.failure is NoArabicVoiceFailure) {
              unawaited(_promptForArabicVoice(context, failureCubit));
            }
          },
        ),
      ],
      child: widget.child,
    );
  }

  Future<void> _promptForArabicVoice(
    BuildContext context,
    PaperVoiceFailureCubit failureCubit,
  ) async {
    final strings = context.strings;
    final canOpenSettings = await failureCubit.canOpenSystemTtsSettings();
    if (!context.mounted) return;

    final wantsSettings = await showActionPromptSheet(
      context,
      title: strings.audioReaderNoArabicVoiceTitle,
      message: strings.audioReaderNoArabicVoiceMessage,
      dismissLabel: strings.audioReaderNoArabicVoiceDismiss,
      actionLabel: canOpenSettings
          ? strings.audioReaderNoArabicVoiceAction
          : null,
    );
    if (!wantsSettings || !context.mounted) return;

    await failureCubit.openSystemTtsSettings();
  }
}
