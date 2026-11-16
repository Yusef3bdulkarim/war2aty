import '../../../features/voice/domain/entities/voice_read_outcome.dart';
import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../papers_repository.dart';

final class RecordPaperReading {
  const RecordPaperReading(this._repository);

  final PapersRepository _repository;

  Future<Result<void, AppFailure>> call({
    required String id,
    required VoiceReadOutcome outcome,
  }) => _repository.recordReading(id: id, outcome: outcome);
}
