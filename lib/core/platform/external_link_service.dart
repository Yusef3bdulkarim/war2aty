/// Sends the user out of the app, to a web page or a mail client.
///
/// The seam exists so that exactly one file imports the plugin that does it
/// (`url_launcher`), the same arrangement `PermissionService` has with
/// `permission_handler`: everything above this speaks [Uri] and a bool.
abstract interface class ExternalLinkService {
  /// Hands [destination] to the platform.
  ///
  /// Answers false when the device has nothing that can open it — a phone
  /// with no browser, or no mail app for a `mailto:` — rather than throwing,
  /// because "nothing can open this" is an ordinary outcome here and the user
  /// has to be told.
  Future<bool> open(Uri destination);
}
