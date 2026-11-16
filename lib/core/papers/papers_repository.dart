import '../../features/voice/domain/entities/voice_read_outcome.dart';
import '../error/app_failure.dart';
import '../result/result.dart';
import 'explain_outcome.dart';
import 'saved_paper.dart';

abstract interface class PapersRepository {
  Stream<Result<List<SavedPaper>, AppFailure>> watchPapers();

  Stream<Result<SavedPaper?, AppFailure>> watchPaper(String id);

  Future<Result<String, AppFailure>> insertPaper({
    String? id,
    required ExplainOutcome outcome,
    required DateTime photographedAt,
    String? encryptedImagePath,
  });

  Future<Result<void, AppFailure>> recordReading({
    required String id,
    required VoiceReadOutcome outcome,
  });

  Future<Result<void, AppFailure>> deletePaper(String id);

  Future<Result<void, AppFailure>> deleteAllPapers();
}
