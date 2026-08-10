import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/usecases/get_hide_sensitive_notification_details.dart';

import '../../../support/fakes.dart';

// F09-T14: the notification-privacy setting's own read side.
void main() {
  test('defaults on (hidden) when the user has never set it', () async {
    final useCase = GetHideSensitiveNotificationDetails(
      FakeNotificationPrivacyStore(),
    );

    expect(await useCase(), isTrue);
  });

  test('reflects an explicit true', () async {
    final useCase = GetHideSensitiveNotificationDetails(
      FakeNotificationPrivacyStore(true),
    );

    expect(await useCase(), isTrue);
  });

  test('reflects an explicit false', () async {
    final useCase = GetHideSensitiveNotificationDetails(
      FakeNotificationPrivacyStore(false),
    );

    expect(await useCase(), isFalse);
  });
}
