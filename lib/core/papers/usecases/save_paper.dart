import 'package:uuid/uuid.dart';

import '../../error/app_failure.dart';
import '../../identity/installation_id_provider.dart';
import '../../result/result.dart';
import '../explain_outcome.dart';
import '../paper_image_store.dart';
import '../papers_repository.dart';

typedef SavePaperOutcome = ({String id, bool imageSaved});

final class SavePaper {
  SavePaper(this._repository, this._images, {IdGenerator? idGenerator})
    : _generateId = idGenerator ?? (() => const Uuid().v4());

  final PapersRepository _repository;
  final PaperImageStore _images;
  final IdGenerator _generateId;

  Future<Result<SavePaperOutcome, AppFailure>> call({
    required ExplainOutcome outcome,
    required DateTime photographedAt,
    required String imagePath,
  }) async {
    final id = _generateId();

    final encrypted = await _images.encryptAndStore(
      paperId: id,
      sourcePath: imagePath,
    );

    final inserted = await _repository.insertPaper(
      id: id,
      outcome: outcome,
      photographedAt: photographedAt,
      encryptedImagePath: encrypted.valueOrNull,
    );

    switch (inserted) {
      case Ok(value: final savedId):
        return Ok((id: savedId, imageSaved: encrypted.isOk));
      case Err(failure: final failure):
        if (encrypted.isOk) await _images.delete(id);
        return Err(failure);
    }
  }
}
