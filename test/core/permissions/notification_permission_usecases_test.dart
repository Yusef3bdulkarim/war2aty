import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/request_notification_permission.dart';

import '../../support/fakes.dart';

void main() {
  test('GetNotificationPermission reads the current status', () async {
    final repository = FakeNotificationPermissionRepository(
      status: PermissionOutcome.denied,
    );
    final useCase = GetNotificationPermission(repository);

    final result = await useCase();

    expect(result.valueOrNull, PermissionOutcome.denied);
    expect(repository.requestCount, 0);
  });

  test(
    'RequestNotificationPermission prompts and reports the answer',
    () async {
      final repository = FakeNotificationPermissionRepository(
        status: PermissionOutcome.denied,
        afterRequest: PermissionOutcome.granted,
      );
      final useCase = RequestNotificationPermission(repository);

      final result = await useCase();

      expect(result.valueOrNull, PermissionOutcome.granted);
      expect(repository.requestCount, 1);
    },
  );
}
