import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/reminder_notification_content.dart';

import '../../support/fakes.dart';

void main() {
  const ar = ArStrings();

  test('hidden: shows only generic copy, never the real title or note', () {
    final content = reminderNotificationContent(
      fakeReminder(),
      ar,
      hideSensitiveDetails: true,
    );

    expect(content.title, ar.reminderNotificationGenericTitle);
    expect(content.body, isNull);
    expect(content.title, isNot(contains('فاتورة')));
  });

  test('revealed: shows the reminder\'s own title and note', () {
    final reminder = fakeReminder();

    final content = reminderNotificationContent(
      reminder,
      ar,
      hideSensitiveDetails: false,
    );

    expect(content.title, 'دفع فاتورة الكهرباء');
  });
}
