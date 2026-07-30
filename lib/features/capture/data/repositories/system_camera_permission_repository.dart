import '../../../../core/error/app_failure.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/camera_permission_repository.dart';

/// [CameraPermissionRepository] on top of the OS permission APIs.
///
/// This is the data boundary: platform channel errors stop here and become a
/// [CameraPermissionFailure], so no exception ever reaches a use case.
final class SystemCameraPermissionRepository
    implements CameraPermissionRepository {
  const SystemCameraPermissionRepository(this._permissions);

  final PermissionService _permissions;

  @override
  Future<Result<PermissionOutcome, AppFailure>> currentStatus() =>
      _guard(() => _permissions.check(AppPermission.camera));

  @override
  Future<Result<PermissionOutcome, AppFailure>> request() =>
      _guard(() => _permissions.request(AppPermission.camera));

  @override
  Future<Result<bool, AppFailure>> openSettings() =>
      _guard(_permissions.openSettings);

  Future<Result<T, AppFailure>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on Object {
      return const Err(CameraPermissionFailure());
    }
  }
}
