import 'package:dio/dio.dart';

import '../models/analysis_request_dto.dart';
import 'analysis_remote_data_source.dart';

/// Path of the analysis endpoint, relative to the functions base URL.
const String kAnalyzeDocumentPath = '/analyze-document';

/// The real transport: `POST /functions/v1/analyze-document` (F06-T13).
///
/// Deliberately thin. Authentication, the correlation id and logging are the
/// [Dio] client's job (`api_client.dart`), and deciding what a status *means*
/// is the repository's — so this only turns a DTO into a request and a
/// response into [AnalysisApiResponse].
///
/// It does not catch [DioException]: the repository maps transport failures
/// through `failureFromDioException`, which is the layer that owns the
/// §31-rule-5 distinction between "offline" and "too slow". Swallowing them
/// here would flatten that into one indistinguishable error.
///
/// PRIVACY: the request carries OCR text and candidates only — no image, no
/// thumbnail, no EXIF, no GPS. `AnalysisRequestDto` has no field that could
/// hold one (§7), which is what makes that guarantee structural rather than a
/// promise this class has to keep.
final class EdgeFunctionAnalysisRemoteDataSource
    implements AnalysisRemoteDataSource {
  const EdgeFunctionAnalysisRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<AnalysisApiResponse> analyze(AnalysisRequestDto request) async {
    final response = await _dio.post<dynamic>(
      kAnalyzeDocumentPath,
      data: request.toJson(),
    );

    return AnalysisApiResponse(
      // A response that somehow arrives without a status is not a success.
      // Defaulting to 200 here would push an unparseable body into the
      // validator and surface as a confusing "invalid response" instead.
      statusCode: response.statusCode ?? 0,
      // Whatever came back. Not assumed to be a JSON object: a gateway can
      // answer with an HTML error page (§31 rule 4), and the repository is
      // built to expect that.
      body: response.data,
    );
  }
}
