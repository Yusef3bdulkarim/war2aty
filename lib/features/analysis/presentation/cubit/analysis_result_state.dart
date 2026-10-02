import '../../../../core/documents/analysis_result.dart';
import '../../../../core/error/app_failure.dart';

/// States of the result screen.
sealed class AnalysisResultState {
  const AnalysisResultState();
}

/// The text is with the analysis service; the screen shows its progress view.
final class AnalysisResultAnalyzing extends AnalysisResultState {
  const AnalysisResultAnalyzing();
}

/// The paper was understood. [result] is ordered and filtered — ready to draw.
final class AnalysisResultReady extends AnalysisResultState {
  const AnalysisResultReady(this.result);

  final AnalysisResult result;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisResultReady && other.result == result;

  @override
  int get hashCode => result.hashCode;
}

/// The analysis did not produce a result.
///
/// [failure] is carried rather than a message: each leaf gets its own screen
/// and its own way out — no internet, daily limit reached, service down,
/// unsupported document.
///
/// [extractedText] travels with it because every one of those ways out ends
/// at the same place: what was read off the paper. Both routes reach the
/// analysis through the OCR review (F20-T19), so it is normally there; when
/// it is empty, the pages simply leave the text out.
final class AnalysisResultFailed extends AnalysisResultState {
  const AnalysisResultFailed(
    this.failure,
    this.extractedText, {
    this.dailyLimit,
  });

  final AppFailure failure;

  /// The normalized OCR text this run was built from.
  final String extractedText;

  /// How many analyses a day the user gets, for the daily-limit page's
  /// wording (F23 #14). Read from the cached usage, and only for a
  /// [DailyLimitReachedFailure]; `null` otherwise, or when the cache has no
  /// usage to give.
  final int? dailyLimit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisResultFailed &&
          other.failure == failure &&
          other.extractedText == extractedText &&
          other.dailyLimit == dailyLimit;

  @override
  int get hashCode => Object.hash(failure, extractedText, dailyLimit);
}
