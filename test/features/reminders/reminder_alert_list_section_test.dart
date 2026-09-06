import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/alert_time_label.dart';
import 'package:war2aty/core/reminders/alert_time_offset.dart';
import 'package:war2aty/features/reminders/presentation/models/reminder_alert_draft.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminder_alert_list_section.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  final event = DateTime.utc(2026, 8, 25, 8);

  // Needs a Material ancestor for its buttons and the sheet it opens, which
  // the real screens' own Scaffold already provides.
  Widget build({
    List<ReminderAlertDraft> alerts = const [],
    DateTime? eventInstant,
    ValueChanged<ReminderAlertDraft>? onAdd,
    ValueChanged<int>? onRemove,
  }) => Scaffold(
    body: ReminderAlertListSection(
      alerts: alerts,
      eventInstant: eventInstant,
      onAdd: onAdd ?? (_) {},
      onRemove: onRemove ?? (_) {},
    ),
  );

  testWidgets('shows a row per alert, earliest label first', (tester) async {
    await pumpApp(
      tester,
      build(
        alerts: [
          ReminderAlertDraft(
            time: event.subtract(const Duration(days: 1)),
            offset: AlertTimeOffset.oneDayBefore,
          ),
        ],
        eventInstant: event,
      ),
    );

    expect(find.text(ar.reminderAlertOffsetOneDay), findsOneWidget);
  });

  testWidgets('shows the add button while under the cap', (tester) async {
    await pumpApp(tester, build(eventInstant: event));

    expect(find.text(ar.reminderAddAnotherAlert), findsOneWidget);
  });

  testWidgets('hides the add button once 3 alerts exist', (tester) async {
    final alerts = [
      for (final offset in AlertTimeOffset.values)
        ReminderAlertDraft(time: offset.applyTo(event), offset: offset),
    ];

    await pumpApp(
      tester,
      build(alerts: alerts.take(3).toList(), eventInstant: event),
    );

    expect(find.text(ar.reminderAddAnotherAlert), findsNothing);
  });

  testWidgets('tapping remove calls onRemove with that alert\'s index', (
    tester,
  ) async {
    int? removedIndex;
    await pumpApp(
      tester,
      build(
        alerts: [
          ReminderAlertDraft(
            time: event.subtract(const Duration(days: 1)),
            offset: AlertTimeOffset.oneDayBefore,
          ),
        ],
        eventInstant: event,
        onRemove: (i) => removedIndex = i,
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(removedIndex, 0);
  });

  testWidgets('opens the offset picker and reports the chosen alert', (
    tester,
  ) async {
    ReminderAlertDraft? added;
    await pumpApp(tester, build(eventInstant: event, onAdd: (a) => added = a));

    await tester.tap(find.text(ar.reminderAddAnotherAlert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ar.reminderAlertOffsetOneDay));
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.offset, AlertTimeOffset.oneDayBefore);
    expect(added!.time, AlertTimeOffset.oneDayBefore.applyTo(event));
  });

  testWidgets('with no event time, the picker offers only a custom time', (
    tester,
  ) async {
    await pumpApp(tester, build());

    await tester.tap(find.text(ar.reminderAddAnotherAlert));
    await tester.pumpAndSettle();

    expect(find.text(ar.reminderAlertOffsetCustom), findsOneWidget);
    expect(find.text(ar.reminderAlertOffsetOneDay), findsNothing);
  });

  testWidgets('a custom alert reads out its actual date and time', (
    tester,
  ) async {
    final custom = ReminderAlertDraft(time: DateTime.utc(2026, 9, 1, 6));

    await pumpApp(tester, build(alerts: [custom], eventInstant: event));

    expect(
      find.text(alertTimeLabel(ar, custom.time, offset: null)),
      findsOneWidget,
    );
  });
}
