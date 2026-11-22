import 'dart:async';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../capture/domain/entities/captured_photo.dart';
import '../usecases/explain_and_save_paper.dart';

final class PaperExplainRunner {
  PaperExplainRunner(this._explainAndSavePaper);

  final ExplainAndSavePaper _explainAndSavePaper;

  StreamController<Result<String, AppFailure>>? _controller;

  bool get isRunning => _controller != null;

  Stream<Result<String, AppFailure>>? join() => _controller?.stream;

  Stream<Result<String, AppFailure>> start(CapturedPhoto photo) {
    if (_controller != null) {
      throw StateError(
        'PaperExplainRunner.start called while a job is already running',
      );
    }

    final controller = StreamController<Result<String, AppFailure>>.broadcast();
    _controller = controller;
    unawaited(_run(photo, controller));
    return controller.stream;
  }

  Future<void> _run(
    CapturedPhoto photo,
    StreamController<Result<String, AppFailure>> controller,
  ) async {
    Result<String, AppFailure> result;
    try {
      result = await _explainAndSavePaper(photo);
    } finally {
      _controller = null;
    }
    controller.add(result);
    await controller.close();
  }
}
