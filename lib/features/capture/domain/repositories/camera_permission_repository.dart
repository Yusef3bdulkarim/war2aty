import '../../../../core/error/app_failure.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/result/result.dart';

/// Camera access, as the capture flow needs it.
///
/// Wraps the platform permission port so the domain never touches a plugin and
/// never sees an exception — platform errors arrive as a typed
/// [CameraPermissionFailure].
abstract interface class CameraPermissionRepository {
  /// The current state, without showing the user anything.
  Future<Result<PermissionOutcome, AppFailure>> currentStatus();

  /// Shows the OS permission prompt and reports the answer.
  Future<Result<PermissionOutcome, AppFailure>> request();

  /// Sends the user to the app's page in the OS settings app, for when the
  /// prompt will not appear again.
  Future<Result<bool, AppFailure>> openSettings();
}
