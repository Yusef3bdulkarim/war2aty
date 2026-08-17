import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/open_notification_permission_settings.dart';
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

  test('OpenNotificationPermissionSettings opens the OS settings page '
      '(F11-T09)', () async {
    final repository = FakeNotificationPermissionRepository(
      status: PermissionOutcome.permanentlyDenied,
    );
    final useCase = OpenNotificationPermissionSettings(repository);

    final result = await useCase();

    expect(result.valueOrNull, isTrue);
    expect(repository.openSettingsCount, 1);
  });
}
