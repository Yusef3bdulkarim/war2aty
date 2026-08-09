import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/permissions/system_notification_permission_repository.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  group('SystemNotificationPermissionRepository', () {
    test('reports the platform status without prompting', () async {
      final permissions = FakePermissionService(
        outcome: PermissionOutcome.granted,
      );
      final repository = SystemNotificationPermissionRepository(permissions);

      expect(
        await repository.currentStatus(),
        const Ok<PermissionOutcome, AppFailure>(PermissionOutcome.granted),
      );
      expect(permissions.requestCount, 0);
    });

    test('asks for notifications, not some other permission', () async {
      final permissions = FakePermissionService(
        outcome: PermissionOutcome.denied,
        requestOutcome: PermissionOutcome.granted,
      );
      final repository = SystemNotificationPermissionRepository(permissions);

      expect(
        await repository.request(),
        const Ok<PermissionOutcome, AppFailure>(PermissionOutcome.granted),
      );
      expect(permissions.requestCount, 1);
    });

    test('turns a platform error into a typed failure', () async {
      final repository = SystemNotificationPermissionRepository(
        FakePermissionService(outcome: PermissionOutcome.denied, fails: true),
      );

      expect(
        (await repository.currentStatus()).failureOrNull,
        const NotificationPermissionFailure(),
      );
      expect(
        (await repository.request()).failureOrNull,
        const NotificationPermissionFailure(),
      );
    });
  });
}
