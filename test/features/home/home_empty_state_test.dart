import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/home/presentation/cubit/home_state.dart';
import 'package:war2aty/features/home/presentation/widgets/home_empty_state.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  const noReminder = ReminderAvailable(null);
  const noDocuments = DocumentsAvailable([]);

  group('isVisible', () {
    test('shown when both sections answered and both are empty', () {
      expect(
        HomeEmptyState.isVisible(reminder: noReminder, documents: noDocuments),
        isTrue,
      );
    });

    test('hidden while either section is still loading', () {
      // Claiming "nothing here" before the answer arrives would flash the
      // wrong message and then yank it away.
      expect(
        HomeEmptyState.isVisible(
          reminder: const ReminderLoading(),
          documents: noDocuments,
        ),
        isFalse,
      );
      expect(
        HomeEmptyState.isVisible(
          reminder: noReminder,
          documents: const DocumentsLoading(),
        ),
        isFalse,
      );
    });

    test('hidden when a section could not be read', () {
      // A failed read is not evidence of emptiness.
      expect(
        HomeEmptyState.isVisible(
          reminder: noReminder,
          documents: const DocumentsUnavailable(LocalDatabaseFailure()),
        ),
        isFalse,
      );
      expect(
        HomeEmptyState.isVisible(
          reminder: const ReminderUnavailable(LocalDatabaseFailure()),
          documents: noDocuments,
        ),
        isFalse,
      );
    });

    test('hidden as soon as anything exists', () {
      expect(
        HomeEmptyState.isVisible(
          reminder: noReminder,
          documents: DocumentsAvailable([documentWith()]),
        ),
        isFalse,
      );
      expect(
        HomeEmptyState.isVisible(
          reminder: ReminderAvailable(reminderWith()),
          documents: noDocuments,
        ),
        isFalse,
      );
    });
  });

  group('HomeEmptyState', () {
    testWidgets('invites the user to scan their first paper', (tester) async {
      await pumpApp(
        tester,
        const HomeEmptyState(reminder: noReminder, documents: noDocuments),
      );

      expect(find.text(ar.homeEmptyTitle), findsOneWidget);
    });

    testWidgets('renders nothing when Home is not empty', (tester) async {
      await pumpApp(
        tester,
        HomeEmptyState(
          reminder: noReminder,
          documents: DocumentsAvailable([documentWith()]),
        ),
      );

      expect(find.text(ar.homeEmptyTitle), findsNothing);
      expect(find.byType(StrokeIcon), findsNothing);
    });

    testWidgets('hides the illustration from screen readers', (tester) async {
      await pumpApp(
        tester,
        const HomeEmptyState(reminder: noReminder, documents: noDocuments),
      );

      // It is decoration; the sentence below already carries the meaning, so
      // the art contributes no node and the icon stays unlabelled.
      expect(find.bySemanticsLabel(ar.homeEmptyTitle), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).semanticLabel,
        isNull,
      );
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        const HomeEmptyState(reminder: noReminder, documents: noDocuments),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.homeEmptyTitle), findsOneWidget);
    });

    testWidgets('survives large text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        const HomeEmptyState(reminder: noReminder, documents: noDocuments),
        locale: AppLocalizations.english,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
