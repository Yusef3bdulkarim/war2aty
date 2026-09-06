import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/widgets/destructive_confirm_sheet.dart';

import '../../support/pump_app.dart';

// F11-T11: the shared destructive-confirmation sheet the settings' delete-all
// rows use, generalized from `showDeleteReminderSheet` (F09-T12).
void main() {
  const title = 'حذف كل شيء؟';
  const message = 'مفيش رجعة بعد كده.';
  const confirmLabel = 'حذف الكل';
  const cancelLabel = 'إلغاء';

  Future<void> openSheet(WidgetTester tester, {bool? Function(bool?)? on}) =>
      pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await showDestructiveConfirmSheet(
                context,
                title: title,
                message: message,
                confirmLabel: confirmLabel,
                cancelLabel: cancelLabel,
              );
              on?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      );

  testWidgets('shows the title, message, and both actions', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text(confirmLabel), findsOneWidget);
    expect(find.text(cancelLabel), findsOneWidget);
  });

  testWidgets('cancel resolves to false and closes the sheet', (tester) async {
    bool? result;
    await openSheet(tester, on: (r) => result = r);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(cancelLabel));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text(title), findsNothing);
  });

  testWidgets('confirming resolves to true', (tester) async {
    bool? result;
    await openSheet(tester, on: (r) => result = r);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(confirmLabel));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
