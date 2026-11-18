import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/voice/usecases/speak_fixed_line.dart';
import '../../../../core/voice/voice_line.dart';
import '../../domain/entities/paper_failure_kind.dart';
import 'paper_failure_state.dart';

final class PaperFailureCubit extends Cubit<PaperFailureState> {
  PaperFailureCubit({
    required SpeakFixedLine speakFixedLine,
    required PaperFailureKind kind,
  }) : _speakFixedLine = speakFixedLine,
       super(const PaperFailureReady()) {
    unawaited(_speakFixedLine(_lineFor(kind)));
  }

  final SpeakFixedLine _speakFixedLine;

  static VoiceLine _lineFor(PaperFailureKind kind) => switch (kind) {
    PaperFailureKind.offline => VoiceLine.failOffline,
    PaperFailureKind.limitReached => VoiceLine.failLimit,
    PaperFailureKind.serviceProblem => VoiceLine.failService,
  };

  @override
  Future<void> close() async {
    await _speakFixedLine.stop();
    return super.close();
  }
}
