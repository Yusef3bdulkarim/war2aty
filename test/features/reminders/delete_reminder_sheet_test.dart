import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/reminders/presentation/widgets/delete_reminder_sheet.dart';

import '../../support/pump_app.dart';

// F09-T12: the «حذف التذكير؟» confirmation sheet.
void main() {
  const ar = ArStrings();

  Future<bool?> capturedResult(WidgetTester tester) async {
    bool? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async =>
              result = await showDeleteReminderSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows the warning and both actions', (tester) async {
    await capturedResult(tester);

    expect(find.text(ar.reminderDeleteSheetTitle), findsOneWidget);
    expect(find.text(ar.reminderDeleteSheetMessage), findsOneWidget);
    expect(find.text(ar.reminderDeleteSheetConfirm), findsOneWidget);
    expect(find.text(ar.reminderDeleteSheetCancel), findsOneWidget);
  });

  testWidgets('cancel resolves to false and closes the sheet', (tester) async {
    bool? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async =>
              result = await showDeleteReminderSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ar.reminderDeleteSheetCancel));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text(ar.reminderDeleteSheetTitle), findsNothing);
  });

  testWidgets('confirming resolves to true', (tester) async {
    bool? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async =>
              result = await showDeleteReminderSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ar.reminderDeleteSheetConfirm));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
