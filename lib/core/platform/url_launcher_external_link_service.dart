import 'package:url_launcher/url_launcher.dart' as launcher;

import 'external_link_service.dart';

/// [ExternalLinkService] backed by the `url_launcher` plugin.
///
/// The only file in the app allowed to import it.
final class UrlLauncherExternalLinkService implements ExternalLinkService {
  const UrlLauncherExternalLinkService();

  @override
  Future<bool> open(Uri destination) => launcher.launchUrl(
    destination,
    // `externalApplication` rather than the default `platformDefault`: the
    // destinations are a policy page and a mail client, both of which belong
    // in the user's own browser or mail app. An in-app web view would also
    // make «الرجوع» ambiguous — the system back would leave the app's own
    // screen rather than the page.
    mode: launcher.LaunchMode.externalApplication,
  );
}
