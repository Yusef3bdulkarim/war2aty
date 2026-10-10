import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/app_strings.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/quick_reminder_date.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/reminders/usecases/complete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/snooze_reminder.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminders.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminders_state.dart';
import 'package:war2aty/features/reminders/presentation/models/manual_reminder_seed.dart';
import 'package:war2aty/features/reminders/presentation/screens/reminders_list_screen.dart';
import 'package:war2aty/features/reminders/presentation/widgets/reminders_empty_art.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';
import '../../support/ui_audit.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
  });
  tearDown(() => repository.dispose());

  Widget screenUnderTest({
    VoidCallback? onAddReminder,
    ValueChanged<String>? onOpenReminder,
    ValueChanged<ManualReminderSeed>? onQuickReminder,
    VoidCallback? onScan,
  }) => BlocProvider<RemindersCubit>(
    create: (_) => RemindersCubit(
      WatchReminders(repository),
      CompleteReminder(repository, scheduler),
      SnoozeReminder(repository, scheduler),
    )..start(),
    child: RemindersListScreen(
      onAddReminder: onAddReminder,
      onOpenReminder: onOpenReminder,
      onQuickReminder: onQuickReminder,
      onScan: onScan,
    ),
  );

  auditScreenLayout('RemindersListScreen', (tester, locale, scaler) {
    repository.emit([
      fakeReminder(alertTimes: [DateTime(2026, 8, 24, 10)]),
      fakeReminder(id: 'r2', status: ReminderStatus.completed),
    ]);
    return pumpApp(
      tester,
      screenUnderTest(),
      locale: locale,
      textScaler: scaler,
    );
  });

  group('RemindersListScreen', () {
    testWidgets('shows a spinner before the database answers', (tester) async {
      await pumpApp(
        tester,
        screenUnderTest(),
        settle: false,
        framesAfterMount: 0,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('always shows the title and add-reminder action', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderListTitle), findsOneWidget);
      // One match: the header button. The empty state no longer carries
      // its own CTA — the header button is always visible above it.
      expect(find.text(ar.reminderAddAction), findsOneWidget);
    });

    testWidgets('shows the empty-library state with nothing saved', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderEmptyTitle), findsOneWidget);
      expect(find.text(ar.reminderEmptySubtitle), findsOneWidget);
    });

    testWidgets('fills the empty library instead of leaving it blank', (
      tester,
    ) async {
      // F29's first complaint: «التذكيرات» with nothing in it was a title and
      // one grey line 80 px down a blank page. Everything asserted here is
      // what now occupies that space.
      await pumpApp(tester, screenUnderTest());

      expect(find.byType(RemindersEmptyArt), findsOneWidget);
      expect(find.text(ar.reminderQuickCreateKicker), findsOneWidget);
      expect(find.text(ar.reminderQuickTomorrow), findsOneWidget);
      expect(find.text(ar.reminderQuickNextWeek), findsOneWidget);
      expect(find.text(ar.reminderQuickEndOfMonth), findsOneWidget);
      expect(find.text(ar.reminderEmptyScanHint), findsOneWidget);
    });

    testWidgets('hides the tabs while nothing is saved at all', (tester) async {
      // Three tabs that each lead to the same nothing are the main reason
      // this screen read as broken (F29, locked decision 5).
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderTabUpcoming), findsNothing);
      expect(find.text(ar.reminderTabMissed), findsNothing);
      expect(find.text(ar.reminderTabCompleted), findsNothing);
    });

    testWidgets('keeps the tabs when only one bucket is empty', (tester) async {
      // The other half of that decision: a user looking at an empty
      // «الفائتة» needs the tabs to get back to «القادمة».
      repository.emit([fakeReminder()]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      expect(find.text(ar.reminderEmptyMissedTitle), findsOneWidget);
      expect(find.text(ar.reminderTabUpcoming), findsOneWidget);
      expect(find.text(ar.reminderTabCompleted), findsOneWidget);
    });

    testWidgets('each quick row carries its own date into the form', (
      tester,
    ) async {
      final seeds = <ManualReminderSeed>[];
      await pumpApp(tester, screenUnderTest(onQuickReminder: seeds.add));

      await tester.tap(find.text(ar.reminderQuickTomorrow));
      await tester.tap(find.text(ar.reminderQuickNextWeek));
      await tester.pumpAndSettle();

      expect(seeds, hasLength(2));
      // Asserted as the gap between two seeds read off the same screen
      // rather than against a date the test computes from its own clock:
      // «بعد أسبوع» is six days past «بكرة», whatever day it is run on, and
      // no reading of `DateTime.now()` here can disagree with the widget's.
      expect(
        seeds[1].eventDate.difference(seeds[0].eventDate).inDays,
        6,
        reason: '${seeds[0]} → ${seeds[1]}',
      );
      for (final seed in seeds) {
        expect(seed.eventMinuteOfDay, kQuickReminderMinuteOfDay);
      }
    });

    testWidgets('offers «صوّر ورقة» only when it has somewhere to send you', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());
      expect(find.text(ar.reminderEmptyScanCta), findsNothing);

      var scans = 0;
      await pumpApp(tester, screenUnderTest(onScan: () => scans++));

      await tester.tap(find.text(ar.reminderEmptyScanCta));
      await tester.pumpAndSettle();

      expect(scans, 1);
    });

    testWidgets('fires onAddReminder from the header button', (tester) async {
      var tapped = 0;
      await pumpApp(tester, screenUnderTest(onAddReminder: () => tapped++));

      await tester.tap(find.text(ar.reminderAddAction));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('says so when the list could not be read', (tester) async {
      repository.emitFailure();

      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderListErrorTitle), findsOneWidget);
      expect(find.text(ar.reminderEmptyTitle), findsNothing);
    });

    testWidgets('lists every upcoming reminder by default', (tester) async {
      final future = DateTime.now().toUtc().add(const Duration(days: 2));
      repository.emit([
        fakeReminder(title: 'فاتورة الكهرباء', alertTimes: [future]),
      ]);

      await pumpApp(tester, screenUnderTest());

      expect(find.text('فاتورة الكهرباء'), findsOneWidget);
      expect(find.text(ar.reminderEmptyTitle), findsNothing);
    });

    testWidgets('switches to the missed bucket on tab tap', (tester) async {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 2));
      repository.emit([
        fakeReminder(title: 'موعد فات', alertTimes: [past]),
      ]);

      await pumpApp(tester, screenUnderTest());
      expect(find.text('موعد فات'), findsNothing);

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      expect(find.text('موعد فات'), findsOneWidget);
    });

    testWidgets('shows the missed tab\'s own empty state', (tester) async {
      repository.emit([fakeReminder()]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      expect(find.text(ar.reminderEmptyMissedTitle), findsOneWidget);
      // Good news said in words as well as in green — the colour is never
      // the message (F29's own rule, and CLAUDE.md's).
      expect(find.text(ar.reminderEmptyMissedSubtitle), findsOneWidget);
      expect(_glyphs(tester), contains(StrokeGlyph.check));
      expect(_glyphs(tester), isNot(contains(StrokeGlyph.checkSquare)));
    });

    testWidgets('shows the completed tab\'s own empty state', (tester) async {
      repository.emit([fakeReminder()]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabCompleted));
      await tester.pumpAndSettle();

      expect(find.text(ar.reminderEmptyCompletedTitle), findsOneWidget);
      expect(find.text(ar.reminderEmptyCompletedSubtitle), findsOneWidget);
      // A different mark from «الفائتة»'s, so the two buckets are not
      // told apart by their tint alone.
      expect(_glyphs(tester), contains(StrokeGlyph.checkSquare));
      expect(_glyphs(tester), isNot(contains(StrokeGlyph.check)));
    });

    testWidgets('an empty bucket leads back to «القادمة»', (tester) async {
      // The old bucket state was one grey line with nowhere to go: a user who
      // tapped «الفائتة» had to find the tab again to get out.
      repository.emit([fakeReminder(title: 'فاتورة الكهرباء')]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ar.reminderEmptyBackToUpcoming));
      await tester.pumpAndSettle();

      expect(find.text('فاتورة الكهرباء'), findsOneWidget);
      expect(find.text(ar.reminderEmptyMissedTitle), findsNothing);
    });

    testWidgets('«القادمة» itself offers no way back to itself', (
      tester,
    ) async {
      // Reachable once every reminder has been missed or completed. It shares
      // the buckets' vocabulary (locked decision 2) but not their link.
      repository.emit([fakeReminder(status: ReminderStatus.completed)]);
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.reminderEmptyTitle), findsOneWidget);
      expect(find.text(ar.reminderEmptyBackToUpcoming), findsNothing);
      expect(_glyphs(tester), contains(StrokeGlyph.navReminders));
    });

    testWidgets('an empty bucket survives large text', (tester) async {
      // The link is a Row of a label and a chevron, which is the one thing in
      // this state that can overflow sideways once the label doubles.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      repository.emit([fakeReminder()]);
      await pumpApp(
        tester,
        screenUnderTest(),
        textScaler: const TextScaler.linear(2),
      );

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(ar.reminderEmptyBackToUpcoming), findsOneWidget);
    });

    testWidgets('no empty bucket carries a shadow', (tester) async {
      // Same rule as the illustrations this feature flattened (F29-T02): the
      // badge is lifted off the page by a border, never by a BoxShadow.
      repository.emit([fakeReminder()]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.reminderTabMissed));
      await tester.pumpAndSettle();

      final shadowed = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow?.isNotEmpty ?? false);

      expect(shadowed, isEmpty);
    });

    testWidgets('opens a reminder when its card is tapped', (tester) async {
      repository.emit([fakeReminder(id: 'rem-9', title: 'فاتورة الكهرباء')]);
      String? opened;

      await pumpApp(
        tester,
        screenUnderTest(onOpenReminder: (id) => opened = id),
      );

      await tester.tap(find.text('فاتورة الكهرباء'));
      await tester.pumpAndSettle();

      expect(opened, 'rem-9');
    });

    testWidgets('lists completed reminders under their own tab', (
      tester,
    ) async {
      repository.emit([
        fakeReminder(
          id: 'done',
          title: 'خلصت',
          status: ReminderStatus.completed,
        ),
      ]);

      await pumpApp(tester, screenUnderTest());
      await tester.tap(find.text(ar.reminderTabCompleted));
      await tester.pumpAndSettle();

      expect(find.text('خلصت'), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        screenUnderTest(),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.reminderListTitle), findsOneWidget);
      expect(find.text(en.reminderEmptyTitle), findsOneWidget);
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final future = DateTime.now().toUtc().add(const Duration(days: 2));
      repository.emit([
        fakeReminder(
          title: 'فاتورة الكهرباء لشهر أغسطس لشقة الدور الخامس',
          alertTimes: [future],
        ),
      ]);

      await pumpApp(
        tester,
        screenUnderTest(),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the filled empty state survives large text too', (
      tester,
    ) async {
      // The state the layout audit above cannot reach — it emits reminders,
      // so the empty library never renders under it. The pane scrolls, so
      // what is checked is that nothing overflows and the first quick row is
      // still on screen rather than pushed under the fold, which is the
      // reason this state is top-anchored instead of centred.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        screenUnderTest(onScan: () {}),
        textScaler: const TextScaler.linear(1.6),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text(ar.reminderQuickTomorrow)).bottom,
        lessThan(640),
      );
    });
  });

  // F29-T12. The tests above were written as each piece landed, so each one
  // checks its own piece in the language and at the scale that piece was
  // built for. Two things none of them can see:
  //
  //  · the layout audit at the top of this file sweeps both languages and
  //    three text scales on a 360×640 phone, but its pump emits reminders —
  //    so no empty state has ever been laid out in **English**, at any
  //    scale, and the one large-text empty-state test is Arabic only;
  //  · nothing checks what a **screen reader** is handed by the assembled
  //    screen. `reminders_empty_art_test` and `reminders_quick_create_test`
  //    cover their own widgets' semantics in isolation, which says nothing
  //    about what the screen wraps around them.
  group('RemindersListScreen · the empty states (F29-T12)', () {
    /// The three states this feature built, and the tab that opens each.
    ///
    /// Named rather than positional because every test below reports which
    /// state failed, and "empty library" is the only useful thing to read in
    /// a failure line.
    const states = <(String, RemindersTab?)>[
      ('the empty library', null),
      ('an empty «الفائتة»', RemindersTab.missed),
      ('an empty «المكتملة»', RemindersTab.completed),
    ];

    /// Puts the screen into one empty state.
    ///
    /// [tab] `null` is the wholly-empty library, which needs an empty
    /// repository. An empty *bucket* needs the opposite: one reminder in
    /// «القادمة», which is what keeps the library non-empty, the tabs on
    /// screen, and both other buckets empty.
    Future<void> pumpEmpty(
      WidgetTester tester,
      RemindersTab? tab, {
      Locale locale = AppLocalizations.arabic,
      TextScaler? textScaler,
    }) async {
      final strings = locale == AppLocalizations.english
          ? const EnStrings() as AppStrings
          : const ArStrings() as AppStrings;
      if (tab != null) repository.emit([fakeReminder()]);

      await pumpApp(
        tester,
        // `onScan` non-null throughout: «صوّر ورقة» is drawn only when the
        // screen has somewhere to send the user, and a state missing its
        // tallest action is not the state being audited.
        screenUnderTest(onScan: () {}, onQuickReminder: (_) {}),
        locale: locale,
        textScaler: textScaler,
      );

      if (tab == null) return;
      await tester.tap(
        find.text(
          tab == RemindersTab.missed
              ? strings.reminderTabMissed
              : strings.reminderTabCompleted,
        ),
      );
      await tester.pumpAndSettle();
    }

    // The gap the audit at the top of this file leaves: its pump emits
    // reminders, so it sweeps the *list*. This is the same sweep — both
    // languages, 1.0/1.5/2.0, on the same 360×640 floor — over the three
    // states that have no list in them. One test per combination, so a
    // failure names the state, the language and the scale.
    for (final (name, tab) in states) {
      for (final locale in kAuditLocales) {
        for (final scale in kAuditTextScales) {
          testWidgets('$name lays out with no overflow — '
              '${locale.languageCode} · text ×$scale', (tester) async {
            setAuditSurface(tester);
            final reported = await recordReportedErrors(
              () => pumpEmpty(
                tester,
                tab,
                locale: locale,
                textScaler: TextScaler.linear(scale),
              ),
            );
            expectNoLayoutError(
              reported,
              '$name — ${locale.languageCode} · text ×$scale',
            );
          });
        }
      }
    }

    testWidgets('the empty library is fully translated', (tester) async {
      // The English test further up asserts the title only, which a state
      // this wordy can pass while still showing Arabic underneath.
      await pumpEmpty(tester, null, locale: AppLocalizations.english);

      for (final line in [
        en.reminderEmptyTitle,
        en.reminderEmptySubtitle,
        en.reminderQuickCreateKicker,
        en.reminderQuickTomorrow,
        en.reminderQuickNextWeek,
        en.reminderQuickEndOfMonth,
        en.reminderEmptyScanCta,
        en.reminderEmptyScanHint,
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
    });

    testWidgets('both empty buckets are fully translated', (tester) async {
      await pumpEmpty(
        tester,
        RemindersTab.missed,
        locale: AppLocalizations.english,
      );

      expect(find.text(en.reminderEmptyMissedTitle), findsOneWidget);
      expect(find.text(en.reminderEmptyMissedSubtitle), findsOneWidget);
      expect(find.text(en.reminderEmptyBackToUpcoming), findsOneWidget);

      await tester.tap(find.text(en.reminderTabCompleted));
      await tester.pumpAndSettle();

      expect(find.text(en.reminderEmptyCompletedTitle), findsOneWidget);
      expect(find.text(en.reminderEmptyCompletedSubtitle), findsOneWidget);
    });

    testWidgets('«صوّر ورقة» reads as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEmpty(tester, null);

      expect(
        tester.getSemantics(find.text(ar.reminderEmptyScanCta)),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label: ar.reminderEmptyScanCta,
        ),
      );

      handle.dispose();
    });

    testWidgets('the way back to «القادمة» reads as a button', (tester) async {
      // Its label and its chevron are two widgets in a Row; what matters is
      // that they arrive as one node a screen reader can act on, not as a
      // sentence followed by an unexplained glyph.
      final handle = tester.ensureSemantics();
      await pumpEmpty(tester, RemindersTab.missed);

      expect(
        tester.getSemantics(find.text(ar.reminderEmptyBackToUpcoming)),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label: ar.reminderEmptyBackToUpcoming,
        ),
      );

      handle.dispose();
    });

    testWidgets('an empty bucket announces its sentence, not its badge', (
      tester,
    ) async {
      // The badge is `ExcludeSemantics` (T10): the tick *is* the message
      // visually, and the title says the same thing in words, so announcing
      // a drawing before it would only delay the sentence.
      final handle = tester.ensureSemantics();
      await pumpEmpty(tester, RemindersTab.missed);

      expect(find.bySemanticsLabel(ar.reminderEmptyMissedTitle), findsOne);
      expect(find.bySemanticsLabel(ar.reminderEmptyMissedSubtitle), findsOne);
      // Every glyph in this state is decoration — the badge's tick and the
      // link's chevron. Neither is allowed a label of its own.
      for (final icon in tester.widgetList<StrokeIcon>(
        find.byType(StrokeIcon),
      )) {
        expect(icon.semanticLabel, isNull, reason: '${icon.glyph}');
      }

      handle.dispose();
    });

    testWidgets('the empty library announces nothing but its own words', (
      tester,
    ) async {
      // The whole state, in reading order: a screen reader swiping through
      // it should hear the title, the explanation, the three dated rows and
      // the two actions — and nothing else. A decoration that leaks a label
      // (the paper, the bell, the calendar marks, the camera) shows up here
      // as an extra node, which is the regression this pins.
      final handle = tester.ensureSemantics();
      await pumpEmpty(tester, null);

      final announced = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label)
          .where((label) => label.isNotEmpty)
          .toList();

      expect(announced, [
        ar.reminderListTitle,
        ar.reminderAddAction,
        ar.reminderEmptyTitle,
        ar.reminderEmptySubtitle,
        ar.reminderQuickCreateKicker,
        // Each row is one node naming its own resolved date — asserted by
        // value in `reminders_quick_create_test`; here only that there are
        // three of them, in order, between the kicker and the actions.
        startsWith(ar.reminderQuickTomorrow),
        startsWith(ar.reminderQuickNextWeek),
        startsWith(ar.reminderQuickEndOfMonth),
        ar.reminderEmptyScanCta,
        ar.reminderEmptyScanHint,
      ]);

      handle.dispose();
    });
  });
}

/// Every stroke glyph currently on screen.
///
/// An empty bucket is told apart by its mark as well as by its tint, so what
/// matters is that the right one is drawn and the other bucket's is not —
/// which is also the check that the two states cannot be distinguished by
/// colour alone.
List<StrokeGlyph> _glyphs(WidgetTester tester) => tester
    .widgetList<StrokeIcon>(find.byType(StrokeIcon))
    .map((icon) => icon.glyph)
    .toList();
