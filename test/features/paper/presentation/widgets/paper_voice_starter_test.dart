import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/core/voice/voice_playback_state.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_state.dart';
import 'package:war2aty/features/paper/presentation/widgets/paper_voice_starter.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';

import '../../../../support/fakes.dart';
import '../../../../support/voice_playback_rig.dart';

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
}
