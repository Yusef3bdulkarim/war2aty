import 'package:dio/dio.dart';

/// Path of the usage endpoint, relative to the functions base URL.
const String kGetUsagePath = '/get-usage';

/// A raw get-usage response: the HTTP status and the decoded body.
///
/// Mirrors `AnalysisApiResponse`: deliberately dumb, so deciding what a status
/// *means* stays one layer up and the shape can be faked in tests.
final class UsageApiResponse {
  const UsageApiResponse({required this.statusCode, required this.body});

  final int statusCode;

  /// Whatever the client decoded. Not assumed to be a JSON object — a gateway
  /// can answer with an HTML error page (§31 rule 4).
  final Object? body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Transport for the get-usage endpoint (API_CONTRACT §32).
abstract interface class UsageRemoteDataSource {
  /// Fetches today's quota for the caller's own anonymous identity.
  ///
  /// May throw on transport problems; the repository translates those.
  Future<UsageApiResponse> fetchUsage();
}

/// The real transport: `GET /functions/v1/get-usage` (F06-T13).
///
/// The user is taken from the verified JWT the [Dio] client attaches, never
/// from a parameter — there is no way to ask for somebody else's quota, and no
/// parameter here that could be made to try.
final class EdgeFunctionUsageRemoteDataSource implements UsageRemoteDataSource {
  const EdgeFunctionUsageRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<UsageApiResponse> fetchUsage() async {
    final response = await _dio.get<dynamic>(kGetUsagePath);

    return UsageApiResponse(
      statusCode: response.statusCode ?? 0,
      body: response.data,
    );
  }
}
