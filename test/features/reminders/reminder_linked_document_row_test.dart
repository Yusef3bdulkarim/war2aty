import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminder_linked_document_row.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  testWidgets('shows the linked document\'s title', (tester) async {
    await pumpApp(
      tester,
      const ReminderLinkedDocumentRow(documentTitle: 'فاتورة كهرباء شهر أغسطس'),
    );

    expect(find.text('فاتورة كهرباء شهر أغسطس'), findsOneWidget);
    expect(find.text(ar.reminderLinkedDocumentSectionLabel), findsOneWidget);
    expect(find.text(ar.reminderLinkedDocumentValueLabel), findsOneWidget);
  });
}
