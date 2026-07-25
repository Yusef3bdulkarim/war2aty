/// Runtime permissions the app asks the user for.
///
/// Only what the app actually requests today. F09 adds `notifications` here
/// when reminders need it — the rest of this file does not change.
enum AppPermission { camera }

/// Where a permission currently stands, collapsed to the three cases the UI
/// has to behave differently for.
///
/// The platform vocabularies are richer than this (iOS `limited`/`provisional`,
/// Android `restricted`), but every one of them folds into "you may use it",
/// "ask again", or "only the OS settings app can change this now".
enum PermissionOutcome {
  granted,

  /// Not granted, but the OS will still show the system prompt if asked.
  denied,

  /// The OS will no longer prompt — the user has to change it in Settings.
  permanentlyDenied,
}

/// Platform port for runtime permissions.
///
/// Pure Dart on purpose: the domain layer talks to this type, so no plugin
/// import leaks past the data layer. The concrete implementation lives in
/// `permission_handler_service.dart`.
abstract interface class PermissionService {
  /// Reads the current state without prompting the user.
  Future<PermissionOutcome> check(AppPermission permission);

  /// Asks the OS to show the system prompt, and reports the answer.
  ///
  /// Returns [PermissionOutcome.permanentlyDenied] without prompting when the
  /// OS has already stopped showing the dialog for [permission].
  Future<PermissionOutcome> request(AppPermission permission);

  /// Opens the app's page in the OS settings app.
  ///
  /// Returns whether the settings app was actually opened.
  Future<bool> openSettings();
}
