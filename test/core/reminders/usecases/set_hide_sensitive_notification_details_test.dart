import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import 'package:war2aty/core/reminders/usecases/set_hide_sensitive_notification_details.dart';

import '../../../support/fakes.dart';

// F09-T14: the notification-privacy setting's own write side.
void main() {
  test('persists the choice for a later read to pick up', () async {
    final store = FakeNotificationPrivacyStore();
    final setUseCase = SetHideSensitiveNotificationDetails(store);
    final getUseCase = GetHideSensitiveNotificationDetails(store);

    await setUseCase(false);

    expect(await getUseCase(), isFalse);
  });

  test('turning it back on is reflected too', () async {
    final store = FakeNotificationPrivacyStore(false);
    final setUseCase = SetHideSensitiveNotificationDetails(store);
    final getUseCase = GetHideSensitiveNotificationDetails(store);

    await setUseCase(true);

    expect(await getUseCase(), isTrue);
  });
}
