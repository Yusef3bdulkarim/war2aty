import '../models/analysis_request_dto.dart';
import 'analysis_remote_data_source.dart';

/// Refuses every analysis, for builds that have no real transport yet.
///
/// Registered in place of the mock outside dev: serving canned fixtures to a
/// real user would present invented amounts and deadlines as if they had been
/// read off their paper, which is the one thing this app must never do.
///
/// Answers with the documented maintenance error, so the existing error mapper
/// turns it into `AnalysisDisabledFailure` and the user sees the normal
/// "الخدمة غير متاحة" copy rather than a crash. Deleted when F06 lands the
/// Edge Function client.
final class DisabledAnalysisRemoteDataSource
    implements AnalysisRemoteDataSource {
  const DisabledAnalysisRemoteDataSource();

  @override
  Future<AnalysisApiResponse> analyze(AnalysisRequestDto request) async {
    return const AnalysisApiResponse(
      statusCode: 503,
      body: {
        'error': {
          'code': 'ANALYSIS_DISABLED',
          'message': 'No analysis transport is wired in this build.',
        },
      },
    );
  }
}
