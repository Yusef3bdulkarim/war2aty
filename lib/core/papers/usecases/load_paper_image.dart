import 'dart:typed_data';

import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../paper_image_store.dart';

final class LoadPaperImage {
  const LoadPaperImage(this._store);

  final PaperImageStore _store;

  Future<Result<Uint8List, AppFailure>> call(String paperId) =>
      _store.load(paperId);
}
