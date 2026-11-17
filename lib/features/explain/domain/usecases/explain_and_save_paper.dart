import 'dart:async';

import '../../../../core/error/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_event.dart';
import '../../../../core/papers/explain_outcome.dart';
import '../../../../core/papers/usecases/save_paper.dart';
import '../../../../core/result/result.dart';
import '../../../../core/usage/usecases/sync_daily_usage.dart';
import '../../../capture/domain/entities/captured_photo.dart';
import '../../../capture/domain/usecases/cleanup_capture_files.dart';
import '../../../capture/domain/usecases/downscale_photo.dart';
import 'explain_paper.dart';

final class ExplainAndSavePaper {
  ExplainAndSavePaper(
    this._downscalePhoto,
    this._explainPaper,
    this._savePaper,
    this._syncDailyUsage,
    this._cleanupCaptureFiles,
    this._logger, {
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final DownscalePhoto _downscalePhoto;
  final ExplainPaper _explainPaper;
  final SavePaper _savePaper;
  final SyncDailyUsage _syncDailyUsage;
  final CleanupCaptureFiles _cleanupCaptureFiles;
  final AppLogger _logger;
  final DateTime Function() _now;

  Future<Result<String, AppFailure>> call(CapturedPhoto photo) async {
    final downscaled = await _downscalePhoto(photo);
    final CapturedPhoto resized;
    switch (downscaled) {
      case Ok(value: final value):
        resized = value;
      case Err(failure: final failure):
        _logger.failure(failure, stage: LogStage.capture);
        return Err(failure);
    }

    final explained = await _explainPaper(resized);
    final ExplainOutcome outcome;
    switch (explained) {
      case Ok(value: final value):
        outcome = value;
      case Err(failure: final failure):
        return Err(failure);
    }

    final saved = await _savePaper(
      outcome: outcome,
      photographedAt: _now(),
      imagePath: resized.path,
    );
    final String paperId;
    switch (saved) {
      case Ok(value: final value):
        paperId = value.id;
      case Err(failure: final failure):
        _logger.failure(failure, stage: LogStage.save);
        return Err(failure);
    }

    unawaited(_syncDailyUsage());
    await _cleanupCaptureFiles({photo.path, resized.path}.toList());

    return Ok(paperId);
  }
}
