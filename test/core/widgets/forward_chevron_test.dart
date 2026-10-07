import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/widgets/forward_chevron.dart';

import '../../support/pump_app.dart';

// F27-T15: `StrokeGlyph.chevronForward` is drawn pointing left, for RTL, and
// `StrokeIcon` mirrors nothing on its own. Four call sites forgot to flip it,
// so in English the "opens something" chevron pointed backwards. These tests
// pin the flip in both directions — the thing no existing test looked at.
void main() {
  /// The x scale the widget's `Transform` applies: -1 when mirrored.
  double xScale(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .ancestor(
              of: find.byType(StrokeIcon),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .storage[0];

  testWidgets('points along the line in Arabic, unflipped', (tester) async {
    await pumpApp(tester, const ForwardChevron(color: Color(0xFF000000)));

    expect(xScale(tester), 1);
  });

  testWidgets('is mirrored in English', (tester) async {
    await pumpApp(
      tester,
      const ForwardChevron(color: Color(0xFF000000)),
      locale: AppLocalizations.english,
    );

    expect(xScale(tester), -1);
  });

  testWidgets('passes size and stroke width through to the glyph', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ForwardChevron(
        color: Color(0xFF112233),
        size: 18,
        strokeWidth: 2.2,
      ),
    );

    final icon = tester.widget<StrokeIcon>(find.byType(StrokeIcon));
    expect(icon.glyph, StrokeGlyph.chevronForward);
    expect(icon.size, 18);
    expect(icon.strokeWidth, 2.2);
    expect(icon.color, const Color(0xFF112233));
  });

  // A grep guard, not a widget test: the glyph is the easy thing to reach for,
  // and reaching for it is how the four broken call sites happened. Anything
  // new that wants a forward chevron should use `ForwardChevron`; the three
  // files listed here predate it and already mirror by hand, which the
  // F12-T02 RTL audit checked.
  test('nothing new uses the raw glyph without mirroring it', () {
    const allowed = {
      // Where the glyph is declared and where it is drawn.
      'lib/core/icons/stroke_icon.dart',
      'lib/core/widgets/forward_chevron.dart',
      // Already mirrored by hand, each with its own `Transform.flip`.
      'lib/features/analysis/presentation/widgets/failure/'
          'extracted_text_entry_card.dart',
      'lib/features/home/presentation/widgets/scan_actions.dart',
      'lib/features/reminders/presentation/screens/reminder_details_screen.dart',
    };

    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map(
          (f) =>
              (path: f.path.replaceAll(r'\', '/'), text: f.readAsStringSync()),
        )
        .where((f) => f.text.contains('StrokeGlyph.chevronForward'))
        .map((f) => f.path)
        .where((path) => !allowed.contains(path))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'These files draw `StrokeGlyph.chevronForward` directly. It points '
          'left, for RTL, and `StrokeIcon` does not flip it — so in English '
          'it points backwards. Use `ForwardChevron` instead: $offenders',
    );
  });
}
