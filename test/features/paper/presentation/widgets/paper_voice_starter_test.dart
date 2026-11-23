import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/usecases/open_system_tts_settings.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/papers/build_paper_voice_segments.dart';
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/papers/usecases/record_paper_reading.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_line.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/core/voice/voice_playback_state.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_state.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_voice_failure_cubit.dart';
import 'package:war2aty/features/paper/presentation/widgets/paper_voice_starter.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_segment.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/voice_playback_rig.dart';

const _ar = ArStrings();

void main() {
  const spans = [
    SpokenCardSpan(
      segmentId: 'explain',
      start: Duration.zero,
      end: Duration(seconds: 4),
      exact: true,
    ),
  ];

  late FakePapersRepository papers;
  late PaperScreenCubit screenCubit;
  late VoicePlaybackRig rig;

  setUp(() {
    papers = FakePapersRepository();
    screenCubit = PaperScreenCubit(
      WatchPaper(papers),
      LoadPaperImage(FakePaperImageStore()),
      RecordPaperReading(papers),
      paperId: 'p1',
    );
    rig = VoicePlaybackRig();
  });

  tearDown(() {
    unawaited(screenCubit.close());
    unawaited(rig.dispose());
  });

  Future<void> pumpStarter(WidgetTester tester, {required bool fresh}) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<PaperScreenCubit>.value(value: screenCubit),
            BlocProvider<VoicePlaybackCubit>.value(value: rig.cubit),
          ],
          child: PaperVoiceStarter(fresh: fresh, child: const SizedBox()),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(rig.settle);
    await tester.pump();
  }

  Future<void> finishRead(
    WidgetTester tester,
    List<VoiceSegment> segments,
  ) async {
    rig.emitWholeLiveRead(segments: segments);
    for (var i = 0; i < 12; i++) {
      await tester.pump();
      await tester.runAsync(rig.settle);
    }
  }

  testWidgets('says nothing while the paper is still loading', (tester) async {
    await pumpStarter(tester, fresh: true);
    await settle(tester);

    expect(rig.cubit.state, const VoicePlaybackIdle());
    expect(rig.liveReadsStarted, 0);
  });

  testWidgets('says nothing for a paper that was not found', (tester) async {
    papers.emitPaper(null);
    screenCubit.start();
    await pumpStarter(tester, fresh: true);
    await settle(tester);

    expect(rig.cubit.state, const VoicePlaybackIdle());
    expect(rig.liveReadsStarted, 0);
  });

  testWidgets('says nothing when the paper failed to load', (tester) async {
    papers.emitPaperFailure();
    screenCubit.start();
    await pumpStarter(tester, fresh: true);
    await settle(tester);

    expect(rig.cubit.state, const VoicePlaybackIdle());
    expect(rig.liveReadsStarted, 0);
  });

  testWidgets('a fresh paper is read aloud once it loads', (tester) async {
    await pumpStarter(tester, fresh: true);
    screenCubit.start();
    papers.emitPaper(savedPaperWith());
    await settle(tester);

    expect(rig.liveReadsStarted, 1);
    expect(rig.replaysLoaded, isEmpty);
    expect(rig.cubit.state, isA<VoicePlaybackStreaming>());
  });

  testWidgets('a paper that is already loaded when the screen opens is read '
      'without waiting for another emission', (tester) async {
    papers.emitPaper(savedPaperWith());
    screenCubit.start();
    await tester.runAsync(rig.settle);
    expect(screenCubit.state, isA<PaperScreenReady>());

    await pumpStarter(tester, fresh: true);
    await settle(tester);

    expect(rig.liveReadsStarted, 1);
  });

  testWidgets('an opened paper with a saved reading replays it with its '
      'stored spans, spending no Live read', (tester) async {
    await pumpStarter(tester, fresh: false);
    screenCubit.start();
    papers.emitPaper(savedPaperWith(audioSaved: true, spans: spans));
    await settle(tester);

    expect(rig.replaysLoaded, ['p1']);
    expect(rig.liveReadsStarted, 0);
    final state = rig.cubit.state as VoicePlaybackFile;
    expect(state.spans, spans);
  });

  testWidgets('an opened paper without a saved reading is read again', (
    tester,
  ) async {
    await pumpStarter(tester, fresh: false);
    screenCubit.start();
    papers.emitPaper(savedPaperWith());
    await settle(tester);

    expect(rig.liveReadsStarted, 1);
    expect(rig.replaysLoaded, isEmpty);
  });

  group('recording the reading', () {
    final paper = savedPaperWith();
    final segments = const BuildPaperVoiceSegments()(paper.explanation);

    testWidgets('nothing is recorded while the paper is still being read', (
      tester,
    ) async {
      await pumpStarter(tester, fresh: true);
      screenCubit.start();
      papers.emitPaper(paper);
      await settle(tester);

      expect(rig.cubit.state, isA<VoicePlaybackStreaming>());
      expect(papers.lastRecordedId, isNull);
    });

    testWidgets('a fresh read that finishes is recorded against the paper', (
      tester,
    ) async {
      await pumpStarter(tester, fresh: true);
      screenCubit.start();
      papers.emitPaper(paper);
      await settle(tester);

      await finishRead(tester, segments);

      final finished = rig.cubit.state as VoicePlaybackReadFinished;
      expect(papers.lastRecordedId, 'p1');
      expect(papers.lastRecordedOutcome, finished.outcome);
    });

    testWidgets('a re-speak of an opened paper that finishes is recorded', (
      tester,
    ) async {
      await pumpStarter(tester, fresh: false);
      screenCubit.start();
      papers.emitPaper(paper);
      await settle(tester);

      await finishRead(tester, segments);

      final finished = rig.cubit.state as VoicePlaybackReadFinished;
      expect(papers.lastRecordedId, 'p1');
      expect(papers.lastRecordedOutcome, finished.outcome);
    });

    testWidgets('replaying a saved reading records nothing', (tester) async {
      await pumpStarter(tester, fresh: false);
      screenCubit.start();
      papers.emitPaper(savedPaperWith(audioSaved: true, spans: spans));
      await settle(tester);

      expect(rig.cubit.state, isA<VoicePlaybackFile>());
      expect(papers.lastRecordedId, isNull);
    });
  });

  testWidgets('a later emission of the same paper does not start it again', (
    tester,
  ) async {
    await pumpStarter(tester, fresh: true);
    screenCubit.start();
    papers.emitPaper(savedPaperWith());
    await settle(tester);

    papers.emitPaper(savedPaperWith(audioSaved: true, spans: spans));
    await settle(tester);

    expect(rig.liveReadsStarted, 1);
    expect(rig.replaysLoaded, isEmpty);
  });

  group('voice failures', () {
    late FakeFixedLinePlayer linePlayer;
    late FakeSystemTtsSettings ttsSettings;
    late FakeTextToSpeechService tts;
    late PaperVoiceFailureCubit failureCubit;

    setUp(() {
      linePlayer = FakeFixedLinePlayer();
      ttsSettings = FakeSystemTtsSettings();
      tts = FakeTextToSpeechService();
      failureCubit = PaperVoiceFailureCubit(
        SpeakFixedLine(linePlayer),
        OpenSystemTtsSettings(ttsSettings, tts),
      );
    });

    tearDown(() async {
      await failureCubit.close();
    });

    Future<void> pumpFailureStarter(WidgetTester tester) async {
      await pumpApp(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider<PaperScreenCubit>.value(value: screenCubit),
            BlocProvider<VoicePlaybackCubit>.value(value: rig.cubit),
            BlocProvider<PaperVoiceFailureCubit>.value(value: failureCubit),
          ],
          child: const PaperVoiceStarter(fresh: true, child: SizedBox()),
        ),
      );
    }

    testWidgets('speaks voice_failed for an ordinary failure', (tester) async {
      rig.failReadWith(const TtsFailure());
      await pumpFailureStarter(tester);
      screenCubit.start();
      papers.emitPaper(savedPaperWith());
      await settle(tester);

      expect(linePlayer.played, [VoiceLine.voiceFailed.assetPath]);
    });

    testWidgets(
      'speaks no_arabic_voice and offers the way to the system settings',
      (tester) async {
        ttsSettings.available = true;
        rig.failReadWith(const NoArabicVoiceFailure());
        await pumpFailureStarter(tester);
        screenCubit.start();
        papers.emitPaper(savedPaperWith());
        await settle(tester);
        await tester.pumpAndSettle();

        expect(linePlayer.played, [VoiceLine.noArabicVoice.assetPath]);
        expect(find.text(_ar.audioReaderNoArabicVoiceTitle), findsOneWidget);
        expect(find.text(_ar.audioReaderNoArabicVoiceAction), findsOneWidget);

        await tester.tap(find.text(_ar.audioReaderNoArabicVoiceAction));
        await tester.pumpAndSettle();

        expect(ttsSettings.openCount, 1);
        expect(tts.forgetVoicesCount, 1);
      },
    );

    testWidgets('offers no action when there is no settings screen to open', (
      tester,
    ) async {
      ttsSettings.available = false;
      rig.failReadWith(const NoArabicVoiceFailure());
      await pumpFailureStarter(tester);
      screenCubit.start();
      papers.emitPaper(savedPaperWith());
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text(_ar.audioReaderNoArabicVoiceTitle), findsOneWidget);
      expect(find.text(_ar.audioReaderNoArabicVoiceAction), findsNothing);
    });
  });
}
