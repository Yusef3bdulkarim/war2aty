import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/home/presentation/cubit/home_state.dart';
import 'package:war2aty/features/home/presentation/widgets/usage_indicator.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  UsageSection available({required int limit, required int remaining}) =>
      UsageAvailable(usageWith(limit: limit, remaining: remaining));

  group('UsageIndicator visibility', () {
    test('hidden while the quota is still loading', () {
      expect(UsageIndicator.isVisible(const UsageLoading()), isFalse);
    });

    test('hidden when the quota could not be read', () {
      expect(
        UsageIndicator.isVisible(
          const UsageUnavailable(LocalDatabaseFailure()),
        ),
        isFalse,
      );
    });

    test('hidden when nothing is cached for today', () {
      expect(UsageIndicator.isVisible(const UsageAvailable(null)), isFalse);
    });

    test('hidden on an untouched quota — there is nothing to explain', () {
      expect(
        UsageIndicator.isVisible(available(limit: 3, remaining: 3)),
        isFalse,
      );
    });

    test('hidden once the quota is spent — the limit screen takes over', () {
      expect(
        UsageIndicator.isVisible(available(limit: 3, remaining: 0)),
        isFalse,
      );
    });

    test('shown midway through the quota', () {
      expect(
        UsageIndicator.isVisible(available(limit: 3, remaining: 1)),
        isTrue,
      );
    });
  });

  group('UsageIndicator', () {
    testWidgets('renders nothing at all when hidden', (tester) async {
      await pumpApp(tester, const UsageIndicator(section: UsageLoading()));

      expect(find.byType(StrokeIcon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the clock and the remaining count', (tester) async {
      await pumpApp(
        tester,
        UsageIndicator(section: available(limit: 3, remaining: 2)),
      );

      expect(find.text(ar.homeUsageRemaining(2)), findsOneWidget);
      final icon = tester.widget<StrokeIcon>(find.byType(StrokeIcon));
      expect(icon.glyph, StrokeGlyph.clock);
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        UsageIndicator(section: available(limit: 3, remaining: 2)),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.homeUsageRemaining(2)), findsOneWidget);
    });

    testWidgets('survives large text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        UsageIndicator(section: available(limit: 12, remaining: 11)),
        locale: AppLocalizations.english,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Arabic counts the noun by number', () {
    test('dual and plural are distinct forms, not "2 تحليلات"', () {
      expect(ar.homeUsageRemaining(1), contains('تحليل واحد'));
      expect(ar.homeUsageRemaining(2), contains('تحليلان'));
      expect(ar.homeUsageRemaining(3), contains('3 تحليلات'));
    });

    test('above ten the noun returns to the singular', () {
      // Reachable if the backend raises the daily limit.
      expect(ar.homeUsageRemaining(10), contains('10 تحليلات'));
      expect(ar.homeUsageRemaining(11), contains('11 تحليلًا'));
    });

    test('a spent quota reads as spent, never as "0 left"', () {
      expect(ar.homeUsageRemaining(0), 'استخدمت تحليلات النهارده.');
      expect(en.homeUsageRemaining(0), isNot(contains('0')));
    });

    test('English keeps singular and plural straight', () {
      expect(en.homeUsageRemaining(1), contains('1 analysis'));
      expect(en.homeUsageRemaining(2), contains('2 analyses'));
    });
  });
}
