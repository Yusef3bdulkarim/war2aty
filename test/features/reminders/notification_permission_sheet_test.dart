import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/reminders/presentation/widgets/notification_permission_sheet.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  testWidgets('shows the title and message, and offers both ways forward', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showNotificationPermissionSheet(
            context,
            onAllow: () {},
            onSaveWithout: () {},
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(ar.reminderNotifPermTitle), findsOneWidget);
    expect(find.text(ar.reminderNotifPermMessage), findsOneWidget);
    expect(find.text(ar.reminderNotifPermAllow), findsOneWidget);
    expect(find.text(ar.reminderNotifPermSaveWithout), findsOneWidget);
  });

  testWidgets('tapping allow closes the sheet and calls onAllow', (
    tester,
  ) async {
    var allowed = false;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showNotificationPermissionSheet(
            context,
            onAllow: () => allowed = true,
            onSaveWithout: () {},
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ar.reminderNotifPermAllow));
    await tester.pumpAndSettle();

    expect(allowed, isTrue);
    expect(find.text(ar.reminderNotifPermTitle), findsNothing);
  });

  testWidgets('tapping save-without closes the sheet and calls onSaveWithout', (
    tester,
  ) async {
    var savedWithout = false;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showNotificationPermissionSheet(
            context,
            onAllow: () {},
            onSaveWithout: () => savedWithout = true,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ar.reminderNotifPermSaveWithout));
    await tester.pumpAndSettle();

    expect(savedWithout, isTrue);
  });
}
