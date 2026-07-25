import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/data/repositories/system_camera_permission_repository.dart';

import '../../support/fakes.dart';

void main() {
  group('SystemCameraPermissionRepository', () {
    test('reports the platform status without prompting', () async {
      final permissions = FakePermissionService(
        outcome: PermissionOutcome.granted,
      );
      final repository = SystemCameraPermissionRepository(permissions);

      expect(
        await repository.currentStatus(),
        const Ok<PermissionOutcome, AppFailure>(PermissionOutcome.granted),
      );
      expect(permissions.requestCount, 0);
    });

    test('asks for the camera, not some other permission', () async {
      final permissions = FakePermissionService(
        outcome: PermissionOutcome.denied,
        requestOutcome: PermissionOutcome.granted,
      );
      final repository = SystemCameraPermissionRepository(permissions);

      expect(
        await repository.request(),
        const Ok<PermissionOutcome, AppFailure>(PermissionOutcome.granted),
      );
      expect(permissions.requestCount, 1);
    });

    test('opens the settings app', () async {
      final permissions = FakePermissionService(
        outcome: PermissionOutcome.granted,
      );
      final repository = SystemCameraPermissionRepository(permissions);

      expect(await repository.openSettings(), const Ok<bool, AppFailure>(true));
      expect(permissions.openSettingsCount, 1);
    });

    test('turns a platform error into a typed failure', () async {
      final repository = SystemCameraPermissionRepository(
        FakePermissionService(outcome: PermissionOutcome.denied, fails: true),
      );

      expect(await repository.currentStatus(), isA<Err<Object, AppFailure>>());
      expect(
        (await repository.currentStatus()).failureOrNull,
        const CameraPermissionFailure(),
      );
      expect(
        (await repository.request()).failureOrNull,
        const CameraPermissionFailure(),
      );
      expect(
        (await repository.openSettings()).failureOrNull,
        const CameraPermissionFailure(),
      );
    });
  });
}
