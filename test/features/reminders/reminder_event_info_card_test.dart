import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminder_event_info_card.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  testWidgets('shows the event date and time when both are known', (
    tester,
  ) async {
    await pumpApp(
      tester,
      ReminderEventInfoCard(
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: 10 * 60,
      ),
    );

    expect(find.textContaining('25'), findsWidgets);
    expect(find.textContaining('10:00'), findsOneWidget);
  });

  testWidgets('says the paper gave no time, rather than guessing one', (
    tester,
  ) async {
    await pumpApp(
      tester,
      ReminderEventInfoCard(
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: null,
      ),
    );

    expect(find.text(ar.reminderEventTimeMissing), findsOneWidget);
    expect(find.textContaining(':'), findsNothing);
  });
}
