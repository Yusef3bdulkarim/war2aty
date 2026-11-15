import 'dart:typed_data';

import '../error/app_failure.dart';
import '../result/result.dart';

abstract interface class PaperImageStore {
  Future<Result<String, AppFailure>> encryptAndStore({
    required String paperId,
    required String sourcePath,
  });

  Future<Result<Uint8List, AppFailure>> load(String paperId);

  Future<void> delete(String paperId);

  Future<void> deleteAll();
}
