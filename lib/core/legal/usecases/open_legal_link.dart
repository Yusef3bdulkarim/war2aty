import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../legal_link_repository.dart';
import '../legal_links.dart';

/// Opens the privacy policy, the terms, or a mail to support (F27-T20).
///
/// One use case over a closed [LegalLink] set rather than three: the only
/// thing that differs is the destination, and a closed set makes this the
/// single audited way the app sends a user outside itself.
final class OpenLegalLink {
  const OpenLegalLink(this._repository);

  final LegalLinkRepository _repository;

  Future<Result<bool, AppFailure>> call(LegalLink link) =>
      _repository.open(link);
}
