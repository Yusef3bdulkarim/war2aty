import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_list_card.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

const _documents = [
  'بطاقة الرقم القومي',
  'أصل شهادة الميلاد',
  'صورتان شخصيتان',
];
const _steps = ['روح لأقرب فرع.', 'قدّم الأوراق في شباك 3.', 'استلم الإيصال.'];

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String title,
    required List<String> items,
    bool numbered = false,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(
      body: ResultListCard(
        glyph: StrokeGlyph.documentCheck,
        title: title,
        items: items,
        numbered: numbered,
      ),
    ),
    textScaler: textScaler,
  );

  group('ResultListCard', () {
    testWidgets('heads the list and shows every line', (tester) async {
      await pumpCard(
        tester,
        title: _strings.resultRequiredDocumentsTitle,
        items: _documents,
      );

      expect(find.text(_strings.resultRequiredDocumentsTitle), findsOneWidget);
      for (final document in _documents) {
        expect(find.text(document), findsOneWidget);
      }
    });

    testWidgets('leaves an unordered list unnumbered', (tester) async {
      await pumpCard(
        tester,
        title: _strings.resultRequiredDocumentsTitle,
        items: _documents,
      );

      expect(find.text('1'), findsNothing);
    });

    testWidgets('numbers steps, because their order is information', (
      tester,
    ) async {
      await pumpCard(
        tester,
        title: _strings.resultInstructionsTitle,
        items: _steps,
        numbered: true,
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('keeps the steps in the order the analysis gave', (
      tester,
    ) async {
      await pumpCard(
        tester,
        title: _strings.resultInstructionsTitle,
        items: _steps,
        numbered: true,
      );

      final first = tester.getTopLeft(find.text(_steps.first));
      final last = tester.getTopLeft(find.text(_steps.last));
      expect(first.dy, lessThan(last.dy));
    });

    testWidgets('lays out long lines under Large Text', (tester) async {
      await pumpCard(
        tester,
        title: _strings.resultInstructionsTitle,
        items: const [
          'قدّم صورة بطاقة الرقم القومي وأصل شهادة الميلاد في مكتب السجل '
              'المدني قبل الموعد المحدد.',
        ],
        numbered: true,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
