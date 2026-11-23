import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/voice/voice_playback_cubit.dart';
import '../cubit/paper_screen_cubit.dart';
import '../cubit/paper_screen_state.dart';
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
    return BlocListener<PaperScreenCubit, PaperScreenState>(
      listener: (_, state) => _startFrom(state),
      child: widget.child,
    );
  }
}
