import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/core/widgets/service_state_view.dart';
import 'package:war2aty/core/widgets/teal_top_bar.dart';

import '../../support/pump_app.dart';

const _title = 'النت فاصل دلوقتي';
const _message = 'علشان نشرح الورقة محتاجين إنترنت.';
const _primary = 'صوّر ورقة تانية';
const _secondary = 'اختار من الصور';
const _tertiary = 'العودة للرئيسية';
const _note = Key('note');
const _blockA = Key('blockA');
const _blockB = Key('blockB');

Future<void> _pump(
  WidgetTester tester, {
  bool withSecondary = true,
  bool paired = false,
  bool withGlyphs = false,
  bool withNote = false,
  List<Widget> content = const [],
  VoidCallback? onBack,
  VoidCallback? onTertiary,
  TextScaler? textScaler,
}) => pumpApp(
  tester,
  Scaffold(
    body: ServiceStateView(
      title: _title,
      message: _message,
      note: withNote ? const SizedBox(key: _note, height: 20) : null,
      content: content,
      pairPrimaryActions: paired,
      onBack: onBack,
      primary: ServiceStateAction(
        label: _primary,
        glyph: withGlyphs ? StrokeGlyph.camera : null,
        onPressed: () {},
      ),
      secondary: withSecondary
          ? ServiceStateAction(
              label: _secondary,
              glyph: withGlyphs ? StrokeGlyph.gallery : null,
              onPressed: () {},
            )
          : null,
      tertiary: ServiceStateAction(
        label: _tertiary,
        onPressed: onTertiary ?? () {},
      ),
    ),
  ),
  textScaler: textScaler,
);

/// Stroke icons drawn outside the teal bar — the old icon panel would be one.
int _iconsOutsideBar() =>
    find.byType(StrokeIcon).evaluate().length -
    find
        .descendant(
          of: find.byType(TealTopBar),
          matching: find.byType(StrokeIcon),
        )
        .evaluate()
        .length;

void main() {
  group('ServiceStateView (F23-T04)', () {
    testWidgets('draws the teal bar, the title as a heading and the message', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(TealTopBar), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_message), findsOneWidget);
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
    });

    testWidgets('has no icon panel above the title', (tester) async {
      await _pump(tester);

      expect(_iconsOutsideBar(), 0);
    });

    testWidgets('the arrow calls onBack', (tester) async {
      var backs = 0;
      await _pump(tester, onBack: () => backs++);

      await tester.tap(find.byType(IconButton).first);

      expect(backs, 1);
    });

    testWidgets('puts the note under the message and the content after it', (
      tester,
    ) async {
      await _pump(
        tester,
        withNote: true,
        content: const [
          SizedBox(key: _blockA, height: 40),
          SizedBox(key: _blockB, height: 40),
        ],
      );

      final message = tester.getRect(find.text(_message));
      final note = tester.getRect(find.byKey(_note));
      final a = tester.getRect(find.byKey(_blockA));
      final b = tester.getRect(find.byKey(_blockB));
      expect(note.top, greaterThan(message.bottom));
      expect(a.top, greaterThan(note.bottom));
      expect(b.top, greaterThan(a.bottom));
    });

    testWidgets('stacks the filled actions by default', (tester) async {
      await _pump(tester);

      final primary = tester.getRect(find.text(_primary));
      final secondary = tester.getRect(find.text(_secondary));
      expect(secondary.top, greaterThan(primary.bottom));
    });

    testWidgets('a pair shares one row, the primary at the start', (
      tester,
    ) async {
      await _pump(tester, paired: true);

      final primary = tester.getCenter(find.text(_primary));
      final secondary = tester.getCenter(find.text(_secondary));
      expect(primary.dy, moreOrLessEquals(secondary.dy));
      // RTL: the start is on the right.
      expect(primary.dx, greaterThan(secondary.dx));
    });

    testWidgets('a pair stacks once the text reaches 1.3×', (tester) async {
      await _pump(
        tester,
        paired: true,
        textScaler: const TextScaler.linear(pairedActionsStackScale),
      );

      final primary = tester.getRect(find.text(_primary));
      final secondary = tester.getRect(find.text(_secondary));
      expect(secondary.top, greaterThan(primary.bottom));
    });

    testWidgets('draws an action\'s glyph beside its label', (tester) async {
      await _pump(tester, paired: true, withGlyphs: true);

      expect(
        find.descendant(
          of: find.widgetWithText(FilledButton, _primary),
          matching: find.byType(StrokeIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the quiet action is readable grey and works', (tester) async {
      var taps = 0;
      await _pump(tester, onTertiary: () => taps++);

      final text = tester.widget<Text>(find.text(_tertiary));
      final style = DefaultTextStyle.of(
        tester.element(find.text(_tertiary)),
      ).style.merge(text.style);
      expect(style.color, AppColors.light.textSecondary);

      await tester.tap(find.text(_tertiary));
      expect(taps, 1);
    });

    testWidgets('fits a small phone at 2.0× text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        paired: true,
        withGlyphs: true,
        withNote: true,
        content: const [SizedBox(height: 300), SizedBox(height: 300)],
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
