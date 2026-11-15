import 'package:dio/dio.dart';

import '../models/explain_request_dto.dart';
import 'explain_remote_data_source.dart';

const String kExplainDocumentPath = '/explain-document';

final class EdgeFunctionExplainRemoteDataSource
    implements ExplainRemoteDataSource {
  const EdgeFunctionExplainRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<ExplainApiResponse> explain(
    ExplainRequestDto request, {
    required Duration timeout,
  }) async {
    final response = await _dio.post<dynamic>(
      kExplainDocumentPath,
      data: request.toJson(),
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );

    return ExplainApiResponse(
      statusCode: response.statusCode ?? 0,
      body: response.data,
    );
  }
}
