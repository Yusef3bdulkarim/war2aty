import '../../../../core/error/app_failure.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/result/result.dart';
import '../repositories/camera_permission_repository.dart';

/// Asks for the camera, after the user has been told why it is needed.
///
/// Only ever called from the explanation sheet — the app does not fire the
/// system prompt at the user before explaining itself.
final class RequestCameraPermission {
  const RequestCameraPermission(this._repository);

  final CameraPermissionRepository _repository;

  Future<Result<PermissionOutcome, AppFailure>> call() => _repository.request();
}
