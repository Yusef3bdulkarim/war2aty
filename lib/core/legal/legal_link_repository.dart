import '../error/app_failure.dart';
import '../result/result.dart';
import 'legal_links.dart';

/// Opens one of the app's published pages, or the support mailbox.
///
/// Pure domain: an interface over [LegalLink] with no notion of how a link is
/// opened, so nothing above the data layer imports a plugin (CLAUDE.md §B1).
abstract interface class LegalLinkRepository {
  /// Opens [link].
  ///
  /// `Ok(false)` means the device had nothing that could open it — a real
  /// outcome, distinct from [ExternalLinkFailure], which is the platform
  /// itself failing.
  Future<Result<bool, AppFailure>> open(LegalLink link);
}
