import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/camera_permission_repository.dart';

/// The way out of a permanent denial: the OS settings page for this app.
///
/// Once the OS stops showing the permission prompt, nothing the app does can
/// bring it back — Settings is the only remaining path to the camera.
final class OpenPermissionSettings {
  const OpenPermissionSettings(this._repository);

  final CameraPermissionRepository _repository;

  Future<Result<bool, AppFailure>> call() => _repository.openSettings();
}
