import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../../../core/storage/analysis_session_storage.dart';
import '../entities/captured_photo.dart';

/// Creates a session directory with a UUID and copies the processed image into
/// it, producing the [AnalysisSession] token that F04 picks up.
final class CreateAnalysisSession {
  const CreateAnalysisSession(this._storage);

  final AnalysisSessionStorage _storage;

  Future<Result<AnalysisSession, AppFailure>> call(CapturedPhoto photo) =>
      _storage.createSession(photo);
}
