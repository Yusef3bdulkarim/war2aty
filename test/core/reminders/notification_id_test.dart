import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/notification_id.dart';

void main() {
  test('is deterministic for the same alert id', () {
    expect(notificationIdOf('a1'), notificationIdOf('a1'));
  });

  test('is never negative — flutter_local_notifications needs a plain int', () {
    for (final id in ['a1', 'a-very-different-alert-id', '', 'z']) {
      expect(notificationIdOf(id), greaterThanOrEqualTo(0));
    }
  });

  test('differs for different alert ids (in the common case)', () {
    expect(notificationIdOf('a1'), isNot(notificationIdOf('a2')));
  });
}
