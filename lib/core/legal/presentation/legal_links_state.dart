import '../legal_links.dart';

/// States of the legal-link rows (F27-T20).
///
/// There is no "opening" state on purpose: handing a `Uri` to the platform
/// returns in a few milliseconds and the browser or mail app then takes the
/// screen, so a spinner would flash and never be read. Only the failing case
/// needs saying out loud.
sealed class LegalLinksState {
  const LegalLinksState();
}

/// Nothing to report — the normal state, including right after a link opened.
final class LegalLinksIdle extends LegalLinksState {
  const LegalLinksIdle();
}

/// [link] could not be opened, so the screen has to say so rather than leave
/// a tap looking ignored.
final class LegalLinkUnavailable extends LegalLinksState {
  const LegalLinkUnavailable(this.link);

  final LegalLink link;

  @override
  bool operator ==(Object other) =>
      other is LegalLinkUnavailable && other.link == link;

  @override
  int get hashCode => link.hashCode;
}
