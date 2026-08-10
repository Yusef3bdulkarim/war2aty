import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminder_text_field.dart';

import '../../support/pump_app.dart';

void main() {
  // A `TextField` needs a Material ancestor, which the real screens' own
  // Scaffold already provides; stand one in here since this test pumps the
  // field on its own (same pattern as `documents_search_field_test.dart`).
  Widget scaffolded(Widget child) => Scaffold(body: child);

  testWidgets('shows the label and the field\'s current text', (tester) async {
    final controller = TextEditingController(text: 'دفع فاتورة الكهرباء');
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      scaffolded(
        ReminderTextField(label: 'عنوان التذكير', controller: controller),
      ),
    );

    expect(find.text('عنوان التذكير'), findsOneWidget);
    expect(find.text('دفع فاتورة الكهرباء'), findsOneWidget);
  });

  testWidgets('shows the hint when the field is empty', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      scaffolded(
        ReminderTextField(
          label: 'عنوان التذكير',
          controller: controller,
          hint: 'مثال: دفع فاتورة الكهرباء',
        ),
      ),
    );

    expect(find.text('مثال: دفع فاتورة الكهرباء'), findsOneWidget);
  });

  testWidgets('marks a required field with an asterisk', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      scaffolded(
        ReminderTextField(
          label: 'عنوان التذكير',
          controller: controller,
          required: true,
        ),
      ),
    );

    expect(find.textContaining('*'), findsOneWidget);
  });

  testWidgets('typing updates the controller', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      scaffolded(ReminderTextField(label: 'ملاحظة', controller: controller)),
    );

    await tester.enterText(find.byType(TextField), 'نص جديد');

    expect(controller.text, 'نص جديد');
  });
}
