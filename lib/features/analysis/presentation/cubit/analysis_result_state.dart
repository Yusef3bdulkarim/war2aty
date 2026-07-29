import '../../../../core/error/app_failure.dart';
import '../../domain/entities/analysis_result.dart';

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
/// at the same place: what the phone read off the paper. The OCR already
/// happened, so the fallback is always available and costs nothing.
final class AnalysisResultFailed extends AnalysisResultState {
  const AnalysisResultFailed(this.failure, this.extractedText);

  final AppFailure failure;

  /// The normalized OCR text this run was built from.
  final String extractedText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisResultFailed &&
          other.failure == failure &&
          other.extractedText == extractedText;

  @override
  int get hashCode => Object.hash(failure, extractedText);
}
