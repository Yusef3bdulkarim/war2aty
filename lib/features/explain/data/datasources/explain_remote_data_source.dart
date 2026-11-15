import '../models/explain_request_dto.dart';

final class ExplainApiResponse {
  const ExplainApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Object? body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract interface class ExplainRemoteDataSource {
  Future<ExplainApiResponse> explain(
    ExplainRequestDto request, {
    required Duration timeout,
  });
}
