import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/core/widgets/skeleton.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/home/presentation/screens/home_screen.dart';
import 'package:war2aty/features/home/presentation/widgets/home_greeting.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakeUsageRepository usage;
  late FakeRecentDocumentsRepository documents;
  late FakeUpcomingReminderRepository reminders;

  setUp(() {
    usage = FakeUsageRepository();
    documents = FakeRecentDocumentsRepository();
    reminders = FakeUpcomingReminderRepository();
  });
  tearDown(() async {
    await usage.dispose();
    await documents.dispose();
    await reminders.dispose();
  });

  /// Home reads its data from a cubit, so tests supply one over a fake stream.
  Widget homeUnderTest() => BlocProvider<HomeCubit>(
    create: (_) => HomeCubit(
      watchDailyUsage: WatchDailyUsage(usage),
      watchRecentDocuments: WatchRecentDocuments(documents),
      watchUpcomingReminder: WatchUpcomingReminder(reminders),
    )..start(),
    child: const HomeScreen(),
  );

  group('HomeScreen', () {
    testWidgets('opens with the greeting, and no app bar', (tester) async {
      await pumpApp(tester, homeUnderTest());

      expect(find.text(ar.homeGreetingTitle), findsOneWidget);
      expect(find.text(ar.homeGreetingSubtitle), findsOneWidget);
      // The design leads with the greeting itself rather than a title bar.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('renders in English, left-to-right', (tester) async {
      await pumpApp(tester, homeUnderTest(), locale: AppLocalizations.english);

      expect(find.text(en.homeGreetingTitle), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(HomeGreeting))),
        TextDirection.ltr,
      );
    });

    testWidgets('lays out right-to-left in Arabic', (tester) async {
      await pumpApp(tester, homeUnderTest());

      expect(
        Directionality.of(tester.element(find.byType(HomeGreeting))),
        TextDirection.rtl,
      );
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        homeUnderTest(),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(ar.homeGreetingTitle), findsOneWidget);
    });

    testWidgets('scrolls, leaving room under the translucent nav bar', (
      tester,
    ) async {
      await pumpApp(tester, homeUnderTest());

      final padding = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .padding!
          .resolve(TextDirection.rtl);

      // Content must clear the bar rather than hide behind it.
      expect(padding.bottom, greaterThan(90));
    });
  });

  group('sections in place', () {
    testWidgets('a fresh install shows the empty state under the actions', (
      tester,
    ) async {
      await pumpApp(tester, homeUnderTest());
      await tester.pumpAndSettle();

      expect(find.text(ar.homeEmptyTitle), findsOneWidget);
      // The way out of the empty state stays available.
      expect(find.text(ar.homeScanTitle), findsOneWidget);
      expect(find.text(ar.homeRecentDocumentsTitle), findsNothing);
      expect(find.text(ar.homeUpcomingReminderTitle), findsNothing);
    });

    testWidgets('saved work replaces the empty state with real sections', (
      tester,
    ) async {
      documents.emit([documentWith(title: 'فاتورة كهرباء')]);
      reminders.emit(reminderWith());

      await pumpApp(tester, homeUnderTest());
      await tester.pumpAndSettle();

      expect(find.text(ar.homeEmptyTitle), findsNothing);
      expect(find.text(ar.homeUpcomingReminderTitle), findsOneWidget);
      expect(find.text(ar.homeRecentDocumentsTitle), findsOneWidget);
      expect(find.text('فاتورة كهرباء'), findsOneWidget);
    });

    testWidgets('the reminder is shown above the documents, as designed', (
      tester,
    ) async {
      documents.emit([documentWith()]);
      reminders.emit(reminderWith());

      await pumpApp(tester, homeUnderTest());
      await tester.pumpAndSettle();

      final reminderY = tester
          .getTopLeft(find.text(ar.homeUpcomingReminderTitle))
          .dy;
      final documentsY = tester
          .getTopLeft(find.text(ar.homeRecentDocumentsTitle))
          .dy;

      // What has a deadline comes before the archive.
      expect(reminderY, lessThan(documentsY));
    });

    testWidgets('nothing is claimed empty while the streams are loading', (
      tester,
    ) async {
      await pumpApp(tester, homeUnderTest(), settle: false);

      // First frame: the answers have not arrived yet.
      expect(find.text(ar.homeEmptyTitle), findsNothing);
      // Placeholders hold the space instead.
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('the placeholders give way, leaving no ticker behind', (
      tester,
    ) async {
      await pumpApp(tester, homeUnderTest(), settle: false);

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(tester.hasRunningAnimations, isTrue);

      documents.emit([documentWith(title: 'فاتورة كهرباء')]);
      reminders.emit(reminderWith());
      await tester.pumpAndSettle();

      expect(find.text('فاتورة كهرباء'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);
      // A shimmer that outlives its placeholders would keep the device
      // redrawing frames behind a screen that has already finished loading.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the scan actions are usable before the data arrives', (
      tester,
    ) async {
      await pumpApp(tester, homeUnderTest(), settle: false);

      // Loading sections must never block the app's main action.
      expect(find.text(ar.homeScanTitle), findsOneWidget);
      expect(find.text(ar.homeGreetingTitle), findsOneWidget);
    });
  });

  group('HomeGreeting', () {
    testWidgets('exposes the title as a header for screen readers', (
      tester,
    ) async {
      await pumpApp(tester, const HomeGreeting());

      expect(
        tester.getSemantics(find.text(ar.homeGreetingTitle)),
        isSemantics(isHeader: true),
      );
    });
  });
}
