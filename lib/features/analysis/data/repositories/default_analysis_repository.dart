import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../../core/documents/analysis_status.dart';
import '../../../../core/documents/document_analysis.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/identity/installation_id_provider.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_event.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/network_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../ocr/domain/entities/extraction_result.dart';
import '../../domain/entities/analysis_image_request.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/repositories/analysis_repository.dart';
import '../datasources/analysis_remote_data_source.dart';
import '../models/amount_candidate_dto.dart';
import '../models/analysis_image_request_dto.dart';
import '../models/analysis_request_dto.dart';
import '../models/candidates_dto.dart';
import '../models/date_candidate_dto.dart';
import '../models/ocr_response_dto.dart';
import '../models/phone_candidate_dto.dart';
import '../models/reference_candidate_dto.dart';
import '../models/time_candidate_dto.dart';
import '../validators/analysis_response_validator.dart';

/// Reads a file's bytes off disk. Injectable so [DefaultAnalysisRepository]
/// can be tested without touching the filesystem.
typedef ImageBytesReader = Future<Uint8List> Function(String path);

Future<Uint8List> _readFileBytes(String path) => File(path).readAsBytes();

/// Strips EXIF metadata — camera make/model, timestamp and, when present,
/// GPS coordinates — before an image leaves the device (F12-T07).
///
/// Nothing upstream of [_buildImageRequest] guarantees this file is clean:
/// a direct camera capture already carries the device's own EXIF block, a
/// gallery pick can carry another app's GPS tag, and neither rotation
/// ([ImagePackageRotator]) nor perspective correction (doclens) is written
/// to strip it — rotation round-trips `image.exif` through its own
/// re-encode, and an undetected page (`quad == null`) skips correction
/// entirely and hands the original file straight through. So this is the one
/// place that can actually promise it, and it is exactly the choke point the
/// class doc below already names as "the one place ... that turns image
/// bytes into something that leaves the device".
///
/// Runs off the UI thread — same reasoning as [ImagePackageRotator]: decode
/// and re-encode is CPU-heavy on a full-resolution photo. Skips the
/// (lossy) re-encode when there is nothing to strip — undecodable bytes, or
/// an image whose `exif` is already empty (doclens's warped output usually
/// has none) — so the common online-review-photo case pays no quality cost.
///
/// `decodeImage` is not a clean "returns null on anything it cannot read":
/// while sniffing an unrecognised or truncated byte sequence it can throw
/// (verified — a 3-byte input drives the PSD probe's header read past the
/// end of the buffer with a raw `RangeError`, before any format is chosen).
/// That must not become an [ImageProcessingFailure] for what is, from this
/// function's point of view, simply "nothing to strip" — [_buildImageRequest]
/// turns any exception here into exactly that failure, which would make a
/// privacy hardening pass newly reject uploads the pre-F12-T07 code accepted.
Future<Uint8List> _stripExif(Uint8List bytes, {required bool isPng}) {
  return Isolate.run(() {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.exif.isEmpty) return bytes;
      decoded.exif.clear();
      // Same JPEG quality as ImagePackageRotator — legible for OCR, not
      // archival, and consistent with the compression a rotated photo
      // already accepts on this same path.
      return isPng
          ? img.encodePng(decoded)
          : img.encodeJpg(decoded, quality: 92);
    } on Object {
      return bytes;
    }
  });
}

/// Request contract version this build speaks (API_CONTRACT §29).
///
/// F13-T09 bumped this to 2.0 (input_type discriminant, rawValue,
/// phones/references). Must move in lockstep with the backend's
/// RuntimeConfig.schemaVersion default — see the migration that flips it.
const String kAnalysisRequestSchemaVersion = '2.0';

/// The one [AnalysisRepository] implementation.
///
/// Builds the request from the OCR result, hands it to whichever
/// [AnalysisRemoteDataSource] is registered — mock today, the Edge Function
/// client from F06 — and turns every outcome into a `Result`. Nothing throws
/// past this class.
final class DefaultAnalysisRepository implements AnalysisRepository {
  const DefaultAnalysisRepository({
    required AnalysisRemoteDataSource dataSource,
    required InstallationIdProvider installationId,
    required AppLogger logger,
    required String appVersion,
    AnalysisResponseValidator validator = const AnalysisResponseValidator(),
    ImageBytesReader readImageBytes = _readFileBytes,
  }) : _dataSource = dataSource,
       _installationId = installationId,
       _logger = logger,
       _appVersion = appVersion,
       _validator = validator,
       _readImageBytes = readImageBytes;

  final AnalysisRemoteDataSource _dataSource;
  final InstallationIdProvider _installationId;
  final AppLogger _logger;
  final String _appVersion;
  final AnalysisResponseValidator _validator;
  final ImageBytesReader _readImageBytes;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    final result = await _analyze(request);

    if (result case Err(:final failure)) {
      _logger.failure(
        failure,
        stage: LogStage.analyze,
        sessionId: request.sessionId,
      );
    }
    return result;
  }

  Future<Result<DocumentAnalysis, AppFailure>> _analyze(
    AnalysisRequest request,
  ) async {
    final identity = await _installationId.getOrCreate();
    if (identity case Err(:final failure)) return Err(failure);

    final dto = _buildRequest(request, identity.valueOrNull!);

    final AnalysisApiResponse response;
    try {
      response = await _dataSource.analyze(dto);
    } on DioException catch (exception) {
      // The transport seam (§31 rule 5): "you are offline" and "this is taking
      // too long" suggest different actions to the user, so they must not
      // collapse into one generic error.
      return Err(failureFromDioException(exception));
    } on TimeoutException {
      return const Err(RequestTimeoutFailure());
    } on Object {
      // Anything a datasource can still throw — a mock's asset load, a JSON
      // decode. The caught object is dropped rather than logged: it can quote
      // the payload that broke, and that payload is the document (§7).
      return const Err(AnalysisServiceFailure());
    }

    if (!response.isSuccess) {
      // The status is passed too: the Supabase gateway rejects an expired token
      // before our function runs, so its 401 body is not a §31 envelope.
      return Err(
        failureFromErrorBody(response.body, statusCode: response.statusCode),
      );
    }

    return _validator.validate(response.body).flatMap(_rejectUnsupported);
  }

  /// A 200 carrying `status: "unsupported"` is a valid response but not a
  /// usable result (§31 rule 6). The result screen shows the OCR-only
  /// fallback, and the attempt does not count against the daily limit.
  Result<DocumentAnalysis, AppFailure> _rejectUnsupported(
    DocumentAnalysis analysis,
  ) {
    if (analysis.status == AnalysisStatus.unsupported) {
      return const Err(UnsupportedDocumentFailure());
    }
    return Ok(analysis);
  }

  /// Assembles the wire request. The image never appears here — [request]
  /// has no field for it (privacy §7).
  AnalysisRequestDto _buildRequest(
    AnalysisRequest request,
    String installationId,
  ) {
    final extraction = request.extraction;

    return AnalysisRequestDto(
      schemaVersion: kAnalysisRequestSchemaVersion,
      sessionId: request.sessionId,
      installationId: installationId,
      appVersion: _appVersion,
      // The cleaned text, not the raw OCR output: normalised digits and
      // whitespace are what the model is prompted against.
      ocrText: extraction.text.cleanedText,
      detectedLanguages: request.detectedLanguages,
      candidates: CandidatesDto(
        dates: extraction.dates.map(DateCandidateDto.fromEntity).toList(),
        times: extraction.times.map(TimeCandidateDto.fromEntity).toList(),
        amounts: extraction.amounts.map(AmountCandidateDto.fromEntity).toList(),
        phones: extraction.phones.map(PhoneCandidateDto.fromEntity).toList(),
        references: extraction.references
            .map(ReferenceCandidateDto.fromEntity)
            .toList(),
      ),
    );
  }

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyzeImage(
    AnalysisImageRequest request,
  ) async {
    final result = await _analyzeImage(request);

    if (result case Err(:final failure)) {
      _logger.failure(
        failure,
        stage: LogStage.analyze,
        sessionId: request.sessionId,
      );
    }
    return result;
  }

  Future<Result<DocumentAnalysis, AppFailure>> _analyzeImage(
    AnalysisImageRequest request,
  ) async {
    final identity = await _installationId.getOrCreate();
    if (identity case Err(:final failure)) return Err(failure);

    final AnalysisImageRequestDto dto;
    try {
      dto = await _buildImageRequest(request, identity.valueOrNull!);
    } on Object {
      // The perspective-corrected file is gone or unreadable before the
      // request ever reaches the wire — an on-device problem, not a
      // transport one.
      return const Err(ImageProcessingFailure());
    }

    final AnalysisApiResponse response;
    try {
      response = await _dataSource.analyzeImage(dto);
    } on DioException catch (exception) {
      return Err(failureFromDioException(exception));
    } on TimeoutException {
      return const Err(RequestTimeoutFailure());
    } on Object {
      return const Err(AnalysisServiceFailure());
    }

    if (!response.isSuccess) {
      return Err(
        failureFromErrorBody(response.body, statusCode: response.statusCode),
      );
    }

    return _validator.validate(response.body).flatMap(_rejectUnsupported);
  }

  /// Assembles the §29b wire request: reads the perspective-corrected file,
  /// strips its EXIF metadata (F12-T07), and base64-encodes it. This is the
  /// one place in the app that turns image bytes into something that leaves
  /// the device (F13 locked decisions).
  Future<AnalysisImageRequestDto> _buildImageRequest(
    AnalysisImageRequest request,
    String installationId,
  ) async {
    final mimeType = _mimeTypeFor(request.photo.path);
    final rawBytes = await _readImageBytes(request.photo.path);
    final bytes = await _stripExif(rawBytes, isPng: mimeType == 'image/png');

    return AnalysisImageRequestDto(
      schemaVersion: kAnalysisRequestSchemaVersion,
      sessionId: request.sessionId,
      installationId: installationId,
      appVersion: _appVersion,
      imageBase64: base64Encode(bytes),
      mimeType: mimeType,
    );
  }

  /// §29b only accepts `image/jpeg` or `image/png`. The online pipeline's own
  /// output is always one of the two — camera capture is JPEG, and a gallery
  /// PNG pick that needed no rotation keeps its original bytes — so the file
  /// extension is a reliable enough signal without decoding the image.
  String _mimeTypeFor(String path) =>
      p.extension(path).toLowerCase() == '.png' ? 'image/png' : 'image/jpeg';

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async {
    final result = await _ocrImage(request);

    if (result case Err(:final failure)) {
      _logger.failure(
        failure,
        stage: LogStage.ocr,
        sessionId: request.sessionId,
      );
    }
    return result;
  }

  Future<Result<ExtractionResult, AppFailure>> _ocrImage(
    AnalysisImageRequest request,
  ) async {
    final identity = await _installationId.getOrCreate();
    if (identity case Err(:final failure)) return Err(failure);

    final AnalysisImageRequestDto dto;
    try {
      // Same wire shape [analyzeImage] sends — this endpoint differs only in
      // where the server stops, not in what the client uploads.
      dto = await _buildImageRequest(request, identity.valueOrNull!);
    } on Object {
      return const Err(ImageProcessingFailure());
    }

    final AnalysisApiResponse response;
    try {
      response = await _dataSource.ocrImage(dto);
    } on DioException catch (exception) {
      return Err(failureFromDioException(exception));
    } on TimeoutException {
      return const Err(RequestTimeoutFailure());
    } on Object {
      return const Err(AnalysisServiceFailure());
    }

    if (!response.isSuccess) {
      return Err(
        failureFromErrorBody(response.body, statusCode: response.statusCode),
      );
    }

    return _parseOcrResponse(response.body);
  }

  /// No [AnalysisResponseValidator] here — that class parses a full
  /// `DocumentAnalysis`, a different wire shape from this endpoint's OCR-only
  /// body. Malformed or unversioned bodies still surface as the same
  /// [InvalidAnalysisResponseFailure] a broken analyze-document body would.
  Result<ExtractionResult, AppFailure> _parseOcrResponse(Object? decodedBody) {
    if (decodedBody is! Map<String, dynamic>) {
      return const Err(InvalidAnalysisResponseFailure());
    }

    final version = decodedBody['schema_version'];
    if (version is! String ||
        !kSupportedAnalysisSchemaVersions.contains(version)) {
      return const Err(InvalidAnalysisResponseFailure());
    }

    try {
      return Ok(OcrResponseDto.fromJson(decodedBody).toExtractionResult());
    } catch (_) {
      // Deliberately catch-all, same reasoning as the analysis validator: the
      // caught object can quote document content and must not be logged (§7).
      return const Err(InvalidAnalysisResponseFailure());
    }
  }
}
