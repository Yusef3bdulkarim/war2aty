import '../error/app_failure.dart';
import '../result/result.dart';
import 'permission_service.dart';

/// Notification access, as the reminders flow needs it (F09-T09).
///
/// Wraps the platform permission port so the domain never touches a plugin
/// and never sees an exception — platform errors arrive as a typed
/// [NotificationPermissionFailure]. Same shape as
/// `CameraPermissionRepository`, for the same reason.
abstract interface class NotificationPermissionRepository {
  /// The current state, without showing the user anything.
  Future<Result<PermissionOutcome, AppFailure>> currentStatus();

  /// Shows the OS permission prompt and reports the answer.
  Future<Result<PermissionOutcome, AppFailure>> request();

  /// Sends the user to the app's page in the OS settings app, for when the
  /// prompt will not appear again (F11-T09).
  Future<Result<bool, AppFailure>> openSettings();
}
