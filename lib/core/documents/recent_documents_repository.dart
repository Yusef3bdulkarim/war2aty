import '../error/app_failure.dart';
import '../result/result.dart';
import 'recent_document.dart';

/// Reads the most recently saved documents.
///
/// A narrow, read-only port: Home only ever needs the newest few, so it does
/// not depend on the full documents repository that F08 will own. When that
/// feature lands it supplies the Drift-backed implementation and this contract
/// stays as it is.
abstract interface class RecentDocumentsRepository {
  /// Emits the newest [limit] documents, then every later change.
  ///
  /// An empty list is a normal value meaning "nothing saved yet"; failures
  /// arrive as `Err` values rather than as stream errors, so a transient
  /// problem cannot tear the stream down.
  Stream<Result<List<RecentDocument>, AppFailure>> watchRecent({int limit});
}
