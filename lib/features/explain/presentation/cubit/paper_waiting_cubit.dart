import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/voice/usecases/speak_fixed_line.dart';
import '../../../../core/voice/voice_line.dart';
import '../../../capture/domain/entities/captured_photo.dart';
import '../../domain/entities/paper_failure_kind.dart';
import '../../domain/services/paper_explain_runner.dart';
import 'paper_waiting_state.dart';

final class PaperWaitingCubit extends Cubit<PaperWaitingState> {
  PaperWaitingCubit({
    required SpeakFixedLine speakFixedLine,
    required PaperExplainRunner runner,
    CapturedPhoto? photo,
  }) : _speakFixedLine = speakFixedLine,
       super(const PaperWaitingInProgress()) {
    _lineFinished = _speakFixedLine.playToEnd(VoiceLine.waitingReading);
    final results =
        runner.join() ?? (photo == null ? null : runner.start(photo));
    if (results == null) {
      unawaited(_fail(PaperFailureKind.serviceProblem));
      return;
    }
    _subscription = results.listen(_onResult);
  }

  final SpeakFixedLine _speakFixedLine;
  late final Future<Object?> _lineFinished;
  StreamSubscription<Result<String, AppFailure>>? _subscription;
  bool _handedOver = false;
  bool _left = false;

  Future<void> _onResult(Result<String, AppFailure> result) async {
    switch (result) {
      case Ok(value: final paperId):
        await _lineFinished;
        _handOver(PaperWaitingNavigateToPaper(paperId));
      case Err(failure: final failure):
        await _fail(PaperFailureKind.fromFailure(failure));
    }
  }

  Future<void> _fail(PaperFailureKind kind) async {
    await _speakFixedLine.stop();
    _handOver(PaperWaitingFailed(kind));
  }

  void _handOver(PaperWaitingState next) {
    if (_left) return;
    _handedOver = true;
    emit(next);
  }

  @override
  Future<void> close() async {
    _left = true;
    await _subscription?.cancel();
    if (!_handedOver) await _speakFixedLine.stop();
    return super.close();
  }
}
