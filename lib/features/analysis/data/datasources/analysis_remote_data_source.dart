import '../models/analysis_request_dto.dart';

/// A raw analyze-document response: the HTTP status and the decoded body.
///
/// Kept deliberately dumb. Deciding what a status or body *means* — success,
/// quota exhausted, unreadable — is the repository's job, so the mock and the
/// real Edge Function client (F06) can share one contract.
final class AnalysisApiResponse {
  const AnalysisApiResponse({required this.statusCode, required this.body});

  final int statusCode;

  /// Whatever `jsonDecode` produced. Not assumed to be a JSON object: a
  /// gateway can answer with an HTML error page (§31 rule 4).
  final Object? body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Transport for the analyze-document endpoint.
abstract interface class AnalysisRemoteDataSource {
  /// Sends [request] and returns the raw response.
  ///
  /// May throw on transport problems (no connection, timeout); the repository
  /// translates those into failures.
  Future<AnalysisApiResponse> analyze(AnalysisRequestDto request);
}
