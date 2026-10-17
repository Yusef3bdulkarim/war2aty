import 'package:flutter_bloc/flutter_bloc.dart';

import '../../result/result.dart';
import '../legal_links.dart';
import '../usecases/open_legal_link.dart';
import 'legal_links_state.dart';

/// Opens the published policy pages and the support mailbox (F27-T20).
///
/// In `core/` rather than in the settings feature because two screens in
/// different places need it — the settings «عن التطبيق» rows and the privacy
/// screen's footer — and a cross-feature import between them would be the
/// thing CLAUDE.md §B1 forbids.
///
/// Depends on a use case only, and never touches `url_launcher` itself.
final class LegalLinksCubit extends Cubit<LegalLinksState> {
  LegalLinksCubit({required OpenLegalLink openLegalLink})
    : _openLegalLink = openLegalLink,
      super(const LegalLinksIdle());

  final OpenLegalLink _openLegalLink;

  /// Opens [link], and reports it when the device cannot.
  ///
  /// Both halves of "it did not open" land in the same state: a platform
  /// failure, and a device with nothing registered for the scheme. The user's
  /// situation is identical either way, and the copy does not pretend to know
  /// which it was.
  Future<void> open(LegalLink link) async {
    // Cleared first, so tapping the same row twice shows the message twice
    // instead of the second tap looking ignored.
    emit(const LegalLinksIdle());

    final result = await _openLegalLink(link);
    final opened = switch (result) {
      Ok(value: final launched) => launched,
      Err() => false,
    };

    if (!opened) emit(LegalLinkUnavailable(link));
  }
}
