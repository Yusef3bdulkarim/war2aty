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

  group('SettingsValueRow', () {
    testWidgets('shows the label and value, with no description by default', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsValueRow(
            glyph: StrokeGlyph.globe,
            label: 'اللغة',
            value: 'العربية',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('اللغة'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('shows a description when given one (F11-T07)', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsValueRow(
            glyph: StrokeGlyph.speaker,
            label: 'صوت القراءة',
            description: 'الأصوات المتاحة حسب إعدادات الموبايل.',
            value: 'الصوت الافتراضي',
            onTap: () {},
          ),
        ),
      );

      expect(
        find.text('الأصوات المتاحة حسب إعدادات الموبايل.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the row fires onTap', (tester) async {
      var tapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsValueRow(
            glyph: StrokeGlyph.globe,
            label: 'اللغة',
            value: 'العربية',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(SettingsValueRow));

      expect(tapped, isTrue);
    });
  });

  group('SettingsActionRow (F11-T07)', () {
    testWidgets('shows the label', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsActionRow(
            glyph: StrokeGlyph.play,
            label: 'تجربة الصوت',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('تجربة الصوت'), findsOneWidget);
    });

    testWidgets('tapping the row fires onTap', (tester) async {
      var tapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: SettingsActionRow(
            glyph: StrokeGlyph.play,
            label: 'تجربة الصوت',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(SettingsActionRow));

      expect(tapped, isTrue);
    });
  });
}
