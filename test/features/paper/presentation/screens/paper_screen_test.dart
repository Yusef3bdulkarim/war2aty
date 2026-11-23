import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/papers/paper_caution.dart';
import 'package:war2aty/core/papers/paper_contact.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_place.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/papers/usecases/record_paper_reading.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/platform/usecases/open_phone_dialer.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/phone_dialer_cubit.dart';
import 'package:war2aty/features/paper/presentation/screens/paper_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/ui_audit.dart';
import '../../../../support/voice_playback_rig.dart';

final Uint8List _onePxPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x00,
  0x00,
  0x02,
  0x00,
  0x01,
  0xE5,
  0x27,
  0xDE,
  0xFC,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakePapersRepository papers;
  late FakePaperImageStore images;
  late PaperScreenCubit cubit;
  late FakeExternalLinkService dialerService;
  late PhoneDialerCubit dialerCubit;
  late VoicePlaybackRig rig;
  late int backCount;
  late DateTime? remindedDate;
  late int? remindedMinuteOfDay;

  setUp(() {
    papers = FakePapersRepository();
    images = FakePaperImageStore();
    backCount = 0;
    remindedDate = null;
    remindedMinuteOfDay = null;
    cubit = PaperScreenCubit(
      WatchPaper(papers),
      LoadPaperImage(images),
      RecordPaperReading(papers),
      paperId: 'p1',
    );
    dialerService = FakeExternalLinkService();
    dialerCubit = PhoneDialerCubit(OpenPhoneDialer(dialerService));
    rig = VoicePlaybackRig();
  });

  tearDown(() async {
    unawaited(cubit.close());
    unawaited(dialerCubit.close());
    unawaited(rig.dispose());
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
    bool settle = true,
  }) => pumpApp(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider<PaperScreenCubit>.value(value: cubit),
        BlocProvider<PhoneDialerCubit>.value(value: dialerCubit),
        BlocProvider<VoicePlaybackCubit>.value(value: rig.cubit),
      ],
      child: PaperScreen(
        onBack: () => backCount++,
        onRemind: (eventDate, eventMinuteOfDay) {
          remindedDate = eventDate;
          remindedMinuteOfDay = eventMinuteOfDay;
        },
      ),
    ),
    locale: locale,
    textScaler: textScaler,
    settle: settle,
  );

  auditScreenLayout('PaperScreen', (tester, locale, scaler) {
    papers.emitPaper(savedPaperWith(savedAt: DateTime.now()));
    cubit.start();
    return pumpScreen(tester, locale: locale, textScaler: scaler);
  });

  group('PaperScreen', () {
    testWidgets('shows a spinner before the database answers', (tester) async {
      await pumpScreen(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the title and header date once it is ready', (
      tester,
    ) async {
      papers.emitPaper(savedPaperWith(savedAt: DateTime.now()));
      cubit.start();

      await pumpScreen(tester);

      expect(find.text('فاتورة كهرباء'), findsOneWidget);
      expect(find.text(ar.paperDateToday), findsOneWidget);
    });

    testWidgets('shows the generic thumbnail when there is no saved image', (
      tester,
    ) async {
      papers.emitPaper(savedPaperWith());
      cubit.start();

      await pumpScreen(tester);

      expect(find.byType(Image), findsNothing);
    });

    testWidgets("shows the paper's photo once it has loaded", (tester) async {
      images.loadResult = _onePxPng;
      papers.emitPaper(savedPaperWith(encryptedImagePath: '/enc/p1'));
      cubit.start();

      await pumpScreen(tester);

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the «؟» button is drawn but does nothing (D6)', (
      tester,
    ) async {
      papers.emitPaper(savedPaperWith());
      cubit.start();

      await pumpScreen(tester);

      final help = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byIcon(Icons.help_outline_rounded),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(help.properties.enabled, isFalse);
    });

    testWidgets('the back button calls onBack', (tester) async {
      papers.emitPaper(savedPaperWith());
      cubit.start();

      await pumpScreen(tester);
      await tester.tap(find.byTooltip(ar.analysisResultBackLabel));

      expect(backCount, 1);
    });

    testWidgets('shows the explain and todo cards in order', (tester) async {
      papers.emitPaper(savedPaperWith());
      cubit.start();

      await pumpScreen(tester);

      final explainCenter = tester.getCenter(
        find.text(ar.paperExplainCardTitle),
      );
      final todoCenter = tester.getCenter(find.text(ar.paperTodoCardTitle));
      expect(explainCenter.dy, lessThan(todoCenter.dy));
      expect(find.text(ar.paperCautionCardTitle), findsNothing);
    });

    testWidgets('shows the caution card when the paper has one', (
      tester,
    ) async {
      papers.emitPaper(
        savedPaperWith(
          explanation: PaperExplanation(
            title: 'جواب من مدرسة النور',
            status: PaperStatus.success,
            paragraphs: const ['دي ورقة من مدرسة النور.'],
            todo: const PaperTodo(required: true, text: 'روح الاجتماع بنفسك.'),
            caution: const PaperCaution(
              text: 'لازم تبلّغ المدرسة قبل الميعاد.',
            ),
          ),
        ),
      );
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.paperCautionCardTitle), findsOneWidget);
      expect(find.text('لازم تبلّغ المدرسة قبل الميعاد.'), findsOneWidget);
    });

    testWidgets('shows the contact card and dials through the call button', (
      tester,
    ) async {
      papers.emitPaper(
        savedPaperWith(
          explanation: PaperExplanation(
            title: 'جواب من مدرسة النور',
            status: PaperStatus.success,
            paragraphs: const ['دي ورقة من مدرسة النور.'],
            todo: const PaperTodo(required: true, text: 'روح الاجتماع بنفسك.'),
            contact: const PaperContact(
              name: 'مدرسة النور',
              phone: '0453312244',
            ),
          ),
        ),
      );
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.paperContactCardTitle), findsOneWidget);
      expect(find.text('مدرسة النور'), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel(ar.paperContactCardCallLabel('مدرسة النور')),
      );
      await tester.pump();

      expect(dialerService.opened, [Uri(scheme: 'tel', path: '0453312244')]);
      expect(find.text(ar.paperContactCardCallFailedMessage), findsNothing);
    });

    testWidgets('shows a short message when the call fails to open', (
      tester,
    ) async {
      dialerService.result = false;
      papers.emitPaper(
        savedPaperWith(
          explanation: PaperExplanation(
            title: 'جواب من مدرسة النور',
            status: PaperStatus.success,
            paragraphs: const ['دي ورقة من مدرسة النور.'],
            todo: const PaperTodo(required: true, text: 'روح الاجتماع بنفسك.'),
            contact: const PaperContact(
              name: 'مدرسة النور',
              phone: '0453312244',
            ),
          ),
        ),
      );
      cubit.start();

      await pumpScreen(tester);
      await tester.tap(
        find.bySemanticsLabel(ar.paperContactCardCallLabel('مدرسة النور')),
      );
      await tester.pump();

      expect(find.text(ar.paperContactCardCallFailedMessage), findsOneWidget);
    });

    testWidgets('shows no date card when the paper has none', (tester) async {
      papers.emitPaper(savedPaperWith());
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.paperDateCardTitle), findsNothing);
    });

    testWidgets('shows the date card and seeds onRemind through the bell', (
      tester,
    ) async {
      papers.emitPaper(
        savedPaperWith(
          explanation: PaperExplanation(
            title: 'جواب من مدرسة النور',
            status: PaperStatus.success,
            paragraphs: const ['دي ورقة من مدرسة النور.'],
            todo: const PaperTodo(required: true, text: 'روح الاجتماع بنفسك.'),
            date: PaperDate(
              day: DateTime.utc(2026, 11, 20),
              time: const PaperTime(hour: 10, minute: 0),
              text: 'اجتماع أولياء الأمور',
            ),
          ),
        ),
      );
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.paperDateCardTitle), findsOneWidget);
      expect(find.text('اجتماع أولياء الأمور'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(ar.paperDateCardBellLabel));

      expect(remindedDate, DateTime.utc(2026, 11, 20));
      expect(remindedMinuteOfDay, 10 * 60);
    });

    testWidgets('shows the place card and opens the enlarged address on tap', (
      tester,
    ) async {
      papers.emitPaper(
        savedPaperWith(
          explanation: PaperExplanation(
            title: 'جواب من مدرسة النور',
            status: PaperStatus.success,
            paragraphs: const ['دي ورقة من مدرسة النور.'],
            todo: const PaperTodo(required: true, text: 'روح الاجتماع بنفسك.'),
            place: const PaperPlace(
              text: 'مدرسة النور، شارع الجمهورية، دمنهور',
            ),
          ),
        ),
      );
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.paperPlaceCardTitle), findsOneWidget);
      expect(find.text('مدرسة النور، شارع الجمهورية، دمنهور'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(ar.paperPlaceCardEnlargeLabel));
      await tester.pumpAndSettle();

      expect(find.text('مدرسة النور، شارع الجمهورية، دمنهور'), findsOneWidget);
      expect(find.text(ar.paperPlaceCardTitle), findsNothing);
    });

    testWidgets('shows a not-found state for a missing paper', (tester) async {
      papers.emitPaper(null);
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.paperScreenNotFoundTitle), findsOneWidget);
      expect(find.text(ar.paperScreenNotFoundMessage), findsOneWidget);

      await tester.tap(find.text(ar.analysisBackToHome));
      expect(backCount, 1);
    });

    testWidgets('shows a not-found state in English', (tester) async {
      papers.emitPaper(null);
      cubit.start();

      await pumpScreen(tester, locale: AppLocalizations.english);

      expect(find.text(en.paperScreenNotFoundTitle), findsOneWidget);
    });

    testWidgets('shows an error state when the database read fails', (
      tester,
    ) async {
      papers.emitPaperFailure();
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.paperScreenErrorTitle), findsOneWidget);
      expect(find.text(ar.paperScreenErrorMessage), findsOneWidget);
    });

    testWidgets('lays out right-to-left by default', (tester) async {
      papers.emitPaper(savedPaperWith());
      cubit.start();

      await pumpScreen(tester);

      expect(
        Directionality.of(tester.element(find.text('فاتورة كهرباء'))),
        TextDirection.rtl,
      );
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      papers.emitPaper(savedPaperWith());
      cubit.start();

      await pumpScreen(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });
  });
}
