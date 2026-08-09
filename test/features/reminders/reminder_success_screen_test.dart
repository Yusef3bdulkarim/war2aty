import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/alert_time_label.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminder_success_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  testWidgets('shows the confirmation, the title and the first alert', (
    tester,
  ) async {
    final reminder = fakeReminder(alertTimes: [DateTime.utc(2026, 8, 24, 8)]);

    await pumpApp(tester, ReminderSuccessScreen(reminder: reminder));

    expect(find.text(ar.reminderSuccessTitle), findsOneWidget);
    expect(find.text('دفع فاتورة الكهرباء'), findsOneWidget);
    expect(
      find.textContaining(
        alertTimeLabel(ar, DateTime.utc(2026, 8, 24, 8), offset: null),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the view button calls onViewReminder', (tester) async {
    var viewed = false;
    await pumpApp(
      tester,
      ReminderSuccessScreen(
        reminder: fakeReminder(),
        onViewReminder: () => viewed = true,
      ),
    );

    await tester.tap(find.text(ar.reminderSuccessViewAction));
    await tester.pump();

    expect(viewed, isTrue);
  });

  testWidgets('the back button calls onClose', (tester) async {
    var closed = false;
    await pumpApp(
      tester,
      ReminderSuccessScreen(
        reminder: fakeReminder(),
        onClose: () => closed = true,
      ),
    );

    await tester.tap(find.text(ar.actionBack));
    await tester.pump();

    expect(closed, isTrue);
  });
}
