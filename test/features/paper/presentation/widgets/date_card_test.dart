import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/paper/presentation/models/paper_view.dart';
import 'package:war2aty/features/paper/presentation/widgets/date_card.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();

const _view = PaperDateCardView(
  month: 'نوفمبر',
  day: '20',
  weekday: 'يوم الخميس',
  text: 'اجتماع أولياء الأمور',
  time: 'الساعة 10 الصبح',
);

Future<void> _pumpCard(
  WidgetTester tester, {
  PaperDateCardView view = _view,
  bool isHighlighted = false,
  VoidCallback? onRemindMe,
  bool settle = true,
}) => pumpApp(
  tester,
  Scaffold(
    body: DateCard(
      view: view,
      onRemindMe: onRemindMe ?? () {},
      isHighlighted: isHighlighted,
    ),
  ),
  settle: settle,
);

void main() {
  group('DateCard', () {
    testWidgets('shows the title, the calendar icon, the badge and weekday', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(find.text(_strings.paperDateCardTitle), findsOneWidget);
      expect(find.text('نوفمبر'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('يوم الخميس'), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon).first).glyph,
        StrokeGlyph.calendar,
      );
    });

    testWidgets('shows the time when the paper gives one', (tester) async {
      await _pumpCard(tester);

      expect(find.text('الساعة 10 الصبح'), findsOneWidget);
    });

    testWidgets('shows no time line when the paper gives none', (tester) async {
      await _pumpCard(
        tester,
        view: const PaperDateCardView(
          month: 'نوفمبر',
          day: '20',
          weekday: 'يوم الخميس',
          text: 'اجتماع أولياء الأمور',
        ),
      );

      expect(find.text('الساعة 10 الصبح'), findsNothing);
    });

    testWidgets("shows the paper's own date.text line", (tester) async {
      await _pumpCard(tester);

      expect(find.text('اجتماع أولياء الأمور'), findsOneWidget);
    });

    testWidgets('is not highlighted by default', (tester) async {
      await _pumpCard(tester);

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsNothing,
      );
    });

    testWidgets('shows the speaking indicator when highlighted', (
      tester,
    ) async {
      await _pumpCard(tester, isHighlighted: true, settle: false);

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsOneWidget,
      );
    });

    testWidgets('the bell is labelled for assistive tech', (tester) async {
      await _pumpCard(tester);

      expect(
        find.bySemanticsLabel(_strings.paperDateCardBellLabel),
        findsOneWidget,
      );
    });

    testWidgets('tapping the bell calls onRemindMe', (tester) async {
      var tapCount = 0;
      await _pumpCard(tester, onRemindMe: () => tapCount++);

      await tester.tap(find.bySemanticsLabel(_strings.paperDateCardBellLabel));

      expect(tapCount, 1);
    });
  });
}
