import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/reminders/presentation/widgets/snooze_sheet.dart';

import '../../support/pump_app.dart';

// F09-T12: the «تأجيل التذكير» sheet.
void main() {
  const ar = ArStrings();

  Future<SnoozeChoice?> openSheet(WidgetTester tester) async {
    SnoozeChoice? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result = await showSnoozeSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows the title, subtitle and every option', (tester) async {
    await openSheet(tester);

    expect(find.text(ar.reminderSnoozeSheetTitle), findsOneWidget);
    expect(find.text(ar.reminderSnoozeSheetSubtitle), findsOneWidget);
    expect(find.text(ar.reminderSnoozeOptionOneHour), findsOneWidget);
    expect(find.text(ar.reminderSnoozeOptionTomorrow), findsOneWidget);
    expect(find.text(ar.reminderSnoozeOptionCustom), findsOneWidget);
  });

  testWidgets('«بعد ساعة» resolves to roughly an hour from now', (
    tester,
  ) async {
    SnoozeChoice? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result = await showSnoozeSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    final before = DateTime.now();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ar.reminderSnoozeOptionOneHour));
    await tester.pumpAndSettle();

    final choice = result;
    expect(choice, isA<SnoozeToTime>());
    final time = (choice as SnoozeToTime).time;
    expect(time.difference(before).inMinutes, inInclusiveRange(59, 61));
  });

  testWidgets('choosing custom pops SnoozeCustom', (tester) async {
    SnoozeChoice? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result = await showSnoozeSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ar.reminderSnoozeOptionCustom));
    await tester.pumpAndSettle();

    expect(result, isA<SnoozeCustom>());
  });
}
