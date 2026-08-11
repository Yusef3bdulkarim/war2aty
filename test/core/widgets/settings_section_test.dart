import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/widgets/settings_section.dart';

import '../../support/pump_app.dart';

void main() {
  group('SettingsSection', () {
    testWidgets('shows the title and every row', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsSection(
            title: 'الخصوصية',
            rows: [
              SettingsToggleRow(
                glyph: StrokeGlyph.send,
                label: 'السماح بإرسال النص للتحليل',
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );

      expect(find.text('الخصوصية'), findsOneWidget);
      expect(find.text('السماح بإرسال النص للتحليل'), findsOneWidget);
    });

    testWidgets('the title reads as a header to assistive tech', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: SettingsSection(title: 'الخصوصية', rows: []),
        ),
      );

      expect(
        tester.getSemantics(find.text('الخصوصية')),
        isSemantics(isHeader: true),
      );
    });
  });

  group('SettingsToggleRow', () {
    testWidgets('reflects the current value', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsToggleRow(
            glyph: StrokeGlyph.send,
            label: 'تفعيل',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('tapping the switch reports the new value', (tester) async {
      bool? reported;
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsToggleRow(
            glyph: StrokeGlyph.send,
            label: 'تفعيل',
            value: true,
            onChanged: (value) => reported = value,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(reported, isFalse);
    });

    testWidgets('a null onChanged disables the row', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: SettingsToggleRow(
            glyph: StrokeGlyph.send,
            label: 'تفعيل',
            value: true,
            onChanged: null,
          ),
        ),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });
  });
}
