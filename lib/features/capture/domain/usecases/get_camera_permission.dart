import '../../../../core/error/app_failure.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/result/result.dart';
import '../repositories/camera_permission_repository.dart';

/// Reads camera access on entering the capture flow, without prompting.
///
/// Silent by design: a user who already granted the camera goes straight to
/// the viewfinder and is never asked again.
final class GetCameraPermission {
  const GetCameraPermission(this._repository);

  final CameraPermissionRepository _repository;

  Future<Result<PermissionOutcome, AppFailure>> call() =>
      _repository.currentStatus();
}
