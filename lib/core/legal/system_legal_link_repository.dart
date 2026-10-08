import '../error/app_failure.dart';
import '../platform/external_link_service.dart';
import '../result/result.dart';
import 'legal_link_repository.dart';
import 'legal_links.dart';

/// [LegalLinkRepository] on top of the platform's own link handling.
///
/// This is the data boundary: a platform-channel error stops here and becomes
/// an [ExternalLinkFailure], so no exception reaches a use case (CLAUDE.md
/// §B5).
final class SystemLegalLinkRepository implements LegalLinkRepository {
  const SystemLegalLinkRepository(this._links);

  final ExternalLinkService _links;

  @override
  Future<Result<bool, AppFailure>> open(LegalLink link) async {
    try {
      return Ok(await _links.open(link.uri));
    } on Object {
      return const Err(ExternalLinkFailure());
    }
  }
}
