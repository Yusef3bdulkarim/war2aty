import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../external_link_service.dart';

final class OpenPhoneDialer {
  const OpenPhoneDialer(this._links);

  final ExternalLinkService _links;

  Future<Result<bool, AppFailure>> call(String phone) async {
    try {
      return Ok(await _links.open(Uri(scheme: 'tel', path: phone)));
    } on Object {
      return const Err(ExternalLinkFailure());
    }
  }
}
