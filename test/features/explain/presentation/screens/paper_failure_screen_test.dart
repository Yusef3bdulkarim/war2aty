import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/explain/domain/entities/paper_failure_kind.dart';
import 'package:war2aty/features/explain/presentation/screens/paper_failure_screen.dart';

import '../../../../support/pump_app.dart';

const _ar = ArStrings();
const _en = EnStrings();

Future<void> _pump(
  WidgetTester tester,
  PaperFailureScreen screen, {
  Locale locale = AppLocalizations.arabic,
  TextScaler? textScaler,
  bool settle = true,
  int framesAfterMount = 1,
}) => pumpApp(
  tester,
  screen,
  locale: locale,
  textScaler: textScaler,
  settle: settle,
  framesAfterMount: framesAfterMount,
);

void main() {
  int retryCalls = 0;
  int homeCalls = 0;

  PaperFailureScreen buildScreen(
    PaperFailureKind kind, {
    DateTime? limitResetAt,
    int? dailyLimit,
  }) => PaperFailureScreen(
    kind: kind,
    onRetry: () => retryCalls++,
    onHome: () => homeCalls++,
    limitResetAt: limitResetAt,
    dailyLimit: dailyLimit,
  );

  setUp(() {
    retryCalls = 0;
    homeCalls = 0;
  });

  group('offline kind', () {
    testWidgets('shows no-internet title and message', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.offline));

      expect(find.text(_ar.analysisNoInternetTitle), findsOneWidget);
      expect(find.text(_ar.paperOfflineMessage), findsOneWidget);
    });

    testWidgets('shows retry and home actions', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.offline));

      expect(find.text(_ar.actionRetry), findsOneWidget);
      expect(find.text(_ar.analysisBackToHome), findsOneWidget);
    });

    testWidgets('retry fires onRetry callback', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.offline));

      await tester.tap(find.text(_ar.actionRetry));
      expect(retryCalls, 1);
      expect(homeCalls, 0);
    });

    testWidgets('home fires onHome callback', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.offline));

      await tester.tap(find.text(_ar.analysisBackToHome));
      expect(homeCalls, 1);
    });

    testWidgets('renders without overflow at large text scale', (tester) async {
      await _pump(
        tester,
        buildScreen(PaperFailureKind.offline),
        textScaler: const TextScaler.linear(2.0),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_ar.analysisNoInternetTitle), findsOneWidget);
    });

    testWidgets('renders correctly in English', (tester) async {
      await _pump(
        tester,
        buildScreen(PaperFailureKind.offline),
        locale: AppLocalizations.english,
      );

      expect(find.text(_en.analysisNoInternetTitle), findsOneWidget);
      expect(find.text(_en.paperOfflineMessage), findsOneWidget);
      expect(find.text(_en.actionRetry), findsOneWidget);
      expect(find.text(_en.analysisBackToHome), findsOneWidget);
    });
  });

  group('serviceProblem kind', () {
    testWidgets('shows service-failed title and message', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.serviceProblem));

      expect(find.text(_ar.analysisFailedTitle), findsOneWidget);
      expect(find.text(_ar.paperServiceFailedMessage), findsOneWidget);
    });

    testWidgets('shows retry and home actions', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.serviceProblem));

      expect(find.text(_ar.actionRetry), findsOneWidget);
      expect(find.text(_ar.analysisBackToHome), findsOneWidget);
    });

    testWidgets('retry fires onRetry callback', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.serviceProblem));

      await tester.tap(find.text(_ar.actionRetry));
      expect(retryCalls, 1);
      expect(homeCalls, 0);
    });

    testWidgets('renders without overflow at large text scale', (tester) async {
      await _pump(
        tester,
        buildScreen(PaperFailureKind.serviceProblem),
        textScaler: const TextScaler.linear(2.0),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_ar.analysisFailedTitle), findsOneWidget);
    });

    testWidgets('renders correctly in English', (tester) async {
      await _pump(
        tester,
        buildScreen(PaperFailureKind.serviceProblem),
        locale: AppLocalizations.english,
      );

      expect(find.text(_en.analysisFailedTitle), findsOneWidget);
      expect(find.text(_en.paperServiceFailedMessage), findsOneWidget);
      expect(find.text(_en.actionRetry), findsOneWidget);
    });

    testWidgets('does not show text-entry card or extracted-text action', (
      tester,
    ) async {
      await _pump(tester, buildScreen(PaperFailureKind.serviceProblem));

      expect(find.text(_ar.resultShowExtractedText), findsNothing);
    });
  });

  group('limitReached kind', () {
    testWidgets('shows limit-reached title and plain message', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.limitReached));

      expect(find.text(_ar.analysisLimitReachedTitle), findsOneWidget);
      expect(find.text(_ar.paperLimitReachedMessage), findsOneWidget);
    });

    testWidgets('names the limit when it is known', (tester) async {
      await _pump(
        tester,
        buildScreen(PaperFailureKind.limitReached, dailyLimit: 3),
      );

      expect(
        find.text(_ar.paperLimitReachedMessageWithLimit(3)),
        findsOneWidget,
      );
    });

    testWidgets('shows only the home action — no retry', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.limitReached));

      expect(find.text(_ar.analysisBackToHome), findsOneWidget);
      expect(find.text(_ar.actionRetry), findsNothing);
    });

    testWidgets('home fires onHome and not onRetry', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.limitReached));

      await tester.tap(find.text(_ar.analysisBackToHome));
      expect(homeCalls, 1);
      expect(retryCalls, 0);
    });

    testWidgets('shows LimitResetCard when resetAt is provided', (
      tester,
    ) async {
      final resetAt = DateTime(2026, 11, 19);
      await _pump(
        tester,
        buildScreen(PaperFailureKind.limitReached, limitResetAt: resetAt),
        settle: false,
      );

      expect(find.text(_ar.analysisLimitResetsInLabel), findsOneWidget);
    });

    testWidgets('no LimitResetCard when resetAt is absent', (tester) async {
      await _pump(tester, buildScreen(PaperFailureKind.limitReached));

      expect(find.text(_ar.analysisLimitResetsInLabel), findsNothing);
    });

    testWidgets('renders without overflow at large text scale', (tester) async {
      await _pump(
        tester,
        buildScreen(PaperFailureKind.limitReached),
        textScaler: const TextScaler.linear(2.0),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_ar.analysisLimitReachedTitle), findsOneWidget);
    });

    testWidgets('renders correctly in English', (tester) async {
      await _pump(
        tester,
        buildScreen(PaperFailureKind.limitReached),
        locale: AppLocalizations.english,
      );

      expect(find.text(_en.analysisLimitReachedTitle), findsOneWidget);
      expect(find.text(_en.paperLimitReachedMessage), findsOneWidget);
      expect(find.text(_en.analysisBackToHome), findsOneWidget);
      expect(find.text(_en.actionRetry), findsNothing);
    });
  });
}
