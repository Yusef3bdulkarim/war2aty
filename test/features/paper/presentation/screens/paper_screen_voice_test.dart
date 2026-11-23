import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/papers/build_paper_voice_segments.dart';
import 'package:war2aty/core/papers/paper_caution.dart';
import 'package:war2aty/core/papers/paper_contact.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_place.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/saved_paper.dart';
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/papers/usecases/record_paper_reading.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/platform/usecases/open_phone_dialer.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/core/voice/voice_playback_state.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/phone_dialer_cubit.dart';
import 'package:war2aty/features/paper/presentation/screens/paper_screen.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_event.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/voice_playback_rig.dart';

const _ar = ArStrings();
const _viewport = Size(400, 560);
const _placeText = 'مدرسة النور، شارع الجمهورية، دمنهور';
const _cardIds = ['explain', 'todo', 'date', 'caution', 'contact', 'place'];

final _spans = [
  for (final (index, id) in _cardIds.indexed)
    SpokenCardSpan(
      segmentId: id,
      start: Duration(seconds: index * 10),
      end: Duration(seconds: index * 10 + 10),
      exact: true,
    ),
];

SavedPaper _paperWithEveryCard() => savedPaperWith(
  savedAt: DateTime.now(),
  explanation: PaperExplanation(
    title: 'جواب من مدرسة النور',
    status: PaperStatus.success,
    paragraphs: [
      for (var i = 0; i < 12; i++)
        'فقرة طويلة بتشرح تفاصيل الورقة رقم $i علشان الشاشة تحتاج تتحرك.',
    ],
    todo: const PaperTodo(required: true, text: 'روح الاجتماع بنفسك.'),
    date: PaperDate(
      day: DateTime.utc(2026, 11, 20),
      time: const PaperTime(hour: 10, minute: 0),
      text: 'اجتماع أولياء الأمور',
    ),
    caution: const PaperCaution(text: 'لازم تبلّغ المدرسة قبل الميعاد.'),
    contact: const PaperContact(name: 'مدرسة النور', phone: '0453312244'),
    place: const PaperPlace(text: _placeText),
  ),
);

void main() {
  late FakePapersRepository papers;
  late PaperScreenCubit screenCubit;
  late PhoneDialerCubit dialerCubit;
  late VoicePlaybackRig rig;

  setUp(() {
    papers = FakePapersRepository();
    screenCubit = PaperScreenCubit(
      WatchPaper(papers),
      LoadPaperImage(FakePaperImageStore()),
      RecordPaperReading(papers),
      paperId: 'p1',
    );
    dialerCubit = PhoneDialerCubit(OpenPhoneDialer(FakeExternalLinkService()));
    rig = VoicePlaybackRig();
  });

  tearDown(() {
    unawaited(screenCubit.close());
    unawaited(dialerCubit.close());
    unawaited(rig.dispose());
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view
      ..physicalSize = _viewport
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final paper = _paperWithEveryCard();
    papers.emitPaper(paper);
    screenCubit.start();
    await pumpApp(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<PaperScreenCubit>.value(value: screenCubit),
          BlocProvider<PhoneDialerCubit>.value(value: dialerCubit),
          BlocProvider<VoicePlaybackCubit>.value(value: rig.cubit),
        ],
        child: PaperScreen(onBack: () {}, onRemind: (_, _) {}),
      ),
    );
  }

  Future<void> advance(WidgetTester tester) async {
    await tester.runAsync(rig.settle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> startFirstReading(
    WidgetTester tester, {
    bool resolveSpans = true,
  }) async {
    rig.readOnDeviceTier();
    unawaited(
      rig.cubit.readAloud(
        segments: const BuildPaperVoiceSegments()(
          _paperWithEveryCard().explanation,
        ),
        audioId: 'p1',
      ),
    );
    await advance(tester);
    if (!resolveSpans) return;
    rig.emitDeviceEvent(VoiceReadSpansResolved(_spans));
    await advance(tester);
  }

  Future<void> speak(WidgetTester tester, String id) async {
    final span = _spans.firstWhere((span) => span.segmentId == id);
    rig.emitDeviceEvent(
      VoiceReadPositionChanged(
        position: span.start + const Duration(seconds: 1),
        segmentId: id,
      ),
    );
    await advance(tester);
  }

  Future<void> startReplay(WidgetTester tester) async {
    unawaited(rig.cubit.replay(audioId: 'p1', spans: _spans));
    await advance(tester);
  }

  bool isOnScreen(WidgetTester tester, Finder finder) {
    final top = tester.getRect(finder).top;
    return top >= 0 && top < _viewport.height;
  }

  Finder segment(String id) => find
      .ancestor(
        of: find.byKey(ValueKey('paper-status-segment-$id')),
        matching: find.byType(GestureDetector),
      )
      .first;

  group('PaperScreen following the voice', () {
    testWidgets('highlights the spoken card and scrolls it into view', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startFirstReading(tester);
      expect(isOnScreen(tester, find.text(_placeText)), isFalse);

      await speak(tester, 'caution');
      await speak(tester, 'place');

      expect(find.bySemanticsLabel(_ar.paperCardSpeakingLabel), findsOneWidget);
      expect(isOnScreen(tester, find.text(_placeText)), isTrue);
    });

    testWidgets(
      'highlights nothing before the spans of the reading are known',
      (tester) async {
        await pumpScreen(tester);
        await startFirstReading(tester, resolveSpans: false);

        expect(find.bySemanticsLabel(_ar.paperCardSpeakingLabel), findsNothing);
      },
    );

    testWidgets('a manual scroll stops the auto-scroll but not the highlight', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startFirstReading(tester);
      await speak(tester, 'explain');

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -40),
      );
      await tester.pump();
      await speak(tester, 'place');

      expect(find.bySemanticsLabel(_ar.paperCardSpeakingLabel), findsOneWidget);
      expect(isOnScreen(tester, find.text(_placeText)), isFalse);
      expect(rig.cubit.state, isA<VoicePlaybackStreaming>());
    });

    testWidgets('a segment tap in the first reading scrolls to its card and '
        'leaves the voice alone', (tester) async {
      await pumpScreen(tester);
      await startFirstReading(tester);
      await speak(tester, 'explain');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -40),
      );
      await tester.pump();

      await tester.tap(segment('contact'));
      await advance(tester);

      expect(isOnScreen(tester, find.text('مدرسة النور').last), isTrue);
      expect(rig.player.seeks, isEmpty);
      expect(rig.cubit.state, isA<VoicePlaybackStreaming>());
      expect((rig.cubit.state as VoicePlaybackStreaming).segmentId, 'explain');
    });

    testWidgets('a segment tap turns the auto-scroll back on', (tester) async {
      await pumpScreen(tester);
      await startFirstReading(tester);
      await speak(tester, 'explain');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -40),
      );
      await tester.pump();

      await tester.tap(segment('todo'));
      await advance(tester);
      await speak(tester, 'place');

      expect(isOnScreen(tester, find.text(_placeText)), isTrue);
    });

    testWidgets('a segment tap in the saved reading jumps the audio to that '
        'card', (tester) async {
      await pumpScreen(tester);
      await startReplay(tester);
      expect(rig.cubit.state, isA<VoicePlaybackFile>());

      await tester.tap(segment('caution'));
      await advance(tester);

      expect(rig.player.seeks, [const Duration(seconds: 30)]);
    });

    testWidgets('the saved reading follows the voice from card to card', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startReplay(tester);

      rig.player.tick(const Duration(seconds: 55));
      await advance(tester);

      expect(find.bySemanticsLabel(_ar.paperCardSpeakingLabel), findsOneWidget);
      expect(isOnScreen(tester, find.text(_placeText)), isTrue);
    });
  });
}
