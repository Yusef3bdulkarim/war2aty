import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/papers/usecases/record_paper_reading.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_line.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_screen_state.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_outcome.dart';

import '../../../../support/fakes.dart';

void main() {
  late FakePapersRepository papers;
  late FakePaperImageStore images;
  late FakeFixedLinePlayer fixedLinePlayer;
  late List<PaperScreenState> states;

  setUp(() {
    papers = FakePapersRepository();
    images = FakePaperImageStore();
    fixedLinePlayer = FakeFixedLinePlayer();
    states = [];
  });

  PaperScreenCubit buildCubit({String paperId = 'p1', bool fresh = true}) {
    final cubit = PaperScreenCubit(
      WatchPaper(papers),
      LoadPaperImage(images),
      RecordPaperReading(papers),
      SpeakFixedLine(fixedLinePlayer),
      paperId: paperId,
      fresh: fresh,
    );
    cubit.stream.listen(states.add);
    return cubit;
  }

  final partialPaper = savedPaperWith(
    explanation: PaperExplanation(
      title: 'فاتورة كهرباء',
      status: PaperStatus.partial,
      paragraphs: const ['الفقرة الأولى.'],
      todo: const PaperTodo(required: true, text: 'روح لأقرب فرع'),
    ),
  );

  final readOutcome = VoiceReadOutcome(
    engine: VoiceEngine.geminiLive,
    duration: const Duration(seconds: 10),
    verified: true,
    audioSaved: true,
    spans: const [],
  );

  test('starts loading before the watcher emits', () {
    final cubit = buildCubit();

    expect(cubit.state, const PaperScreenLoading());
  });

  test('watches the requested paper id', () async {
    final cubit = buildCubit(paperId: 'p42');
    cubit.start();
    await pumpEventQueue();

    expect(papers.requestedPaperId, 'p42');

    await cubit.close();
  });

  test('a paper with no stored image never asks to load one', () async {
    final cubit = buildCubit();
    cubit.start();

    papers.emitPaper(savedPaperWith());
    await pumpEventQueue();

    expect(states, [
      isA<PaperScreenReady>().having((s) => s.imageBytes, 'imageBytes', null),
    ]);
    expect(images.loadCallCount, 0);

    await cubit.close();
  });

  test(
    'loads the image for a paper that has one, then re-emits with it',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      images.loadResult = bytes;
      final cubit = buildCubit();
      cubit.start();

      papers.emitPaper(savedPaperWith(encryptedImagePath: '/enc/p1'));
      await pumpEventQueue();

      expect(states, hasLength(2));
      expect((states[0] as PaperScreenReady).imageBytes, isNull);
      expect((states[1] as PaperScreenReady).imageBytes, bytes);
      expect(images.loadCallCount, 1);

      await cubit.close();
    },
  );

  test('records a reading against the paper it was opened for', () async {
    final cubit = buildCubit(paperId: 'p42');
    final outcome = VoiceReadOutcome(
      engine: VoiceEngine.geminiLive,
      duration: const Duration(seconds: 75),
      verified: true,
      audioSaved: true,
      spans: const [],
    );

    await cubit.recordReading(outcome);

    expect(papers.lastRecordedId, 'p42');
    expect(papers.lastRecordedOutcome, same(outcome));

    await cubit.close();
  });

  test(
    'recording a reading against a partial paper speaks explain_partial',
    () async {
      final cubit = buildCubit();
      cubit.start();
      papers.emitPaper(
        savedPaperWith(
          explanation: PaperExplanation(
            title: 'فاتورة كهرباء',
            status: PaperStatus.partial,
            paragraphs: const ['الفقرة الأولى.'],
            todo: const PaperTodo(required: true, text: 'روح لأقرب فرع'),
          ),
        ),
      );
      await pumpEventQueue();

      await cubit.recordReading(
        VoiceReadOutcome(
          engine: VoiceEngine.geminiLive,
          duration: const Duration(seconds: 10),
          verified: true,
          audioSaved: true,
          spans: const [],
        ),
      );
      await pumpEventQueue();

      expect(fixedLinePlayer.played, [VoiceLine.explainPartial.assetPath]);

      await cubit.close();
    },
  );

  test('a device-TTS re-speak does not repeat explain_partial', () async {
    final cubit = buildCubit();
    cubit.start();
    papers.emitPaper(partialPaper);
    await pumpEventQueue();

    await cubit.recordReading(readOutcome);
    await pumpEventQueue();
    await cubit.recordReading(readOutcome);
    await pumpEventQueue();

    expect(fixedLinePlayer.played, [VoiceLine.explainPartial.assetPath]);

    await cubit.close();
  });

  test('an opened partial paper never speaks explain_partial', () async {
    final cubit = buildCubit(fresh: false);
    cubit.start();
    papers.emitPaper(partialPaper);
    await pumpEventQueue();

    await cubit.recordReading(readOutcome);
    await pumpEventQueue();

    expect(fixedLinePlayer.played, isEmpty);

    await cubit.close();
  });

  test('recording a reading against a success paper stays silent', () async {
    final cubit = buildCubit();
    cubit.start();
    papers.emitPaper(savedPaperWith());
    await pumpEventQueue();

    await cubit.recordReading(
      VoiceReadOutcome(
        engine: VoiceEngine.geminiLive,
        duration: const Duration(seconds: 10),
        verified: true,
        audioSaved: true,
        spans: const [],
      ),
    );
    await pumpEventQueue();

    expect(fixedLinePlayer.played, isEmpty);

    await cubit.close();
  });

  test('a reading that fails to record leaves the screen as it was', () async {
    papers.recordReadingOutcome = const Err(LocalDatabaseFailure());
    final cubit = buildCubit();
    cubit.start();
    papers.emitPaper(
      savedPaperWith(
        explanation: PaperExplanation(
          title: 'فاتورة كهرباء',
          status: PaperStatus.partial,
          paragraphs: const ['الفقرة الأولى.'],
          todo: const PaperTodo(required: true, text: 'روح لأقرب فرع'),
        ),
      ),
    );
    await pumpEventQueue();
    states.clear();

    await cubit.recordReading(
      VoiceReadOutcome(
        engine: VoiceEngine.deviceTts,
        duration: const Duration(seconds: 10),
        verified: true,
        audioSaved: false,
        spans: const [],
      ),
    );
    await pumpEventQueue();

    expect(states, isEmpty);
    expect(cubit.state, isA<PaperScreenReady>());
    expect(fixedLinePlayer.played, isEmpty);

    await cubit.close();
  });

  test('a failed image decrypt keeps the paper ready with no image', () async {
    images.fails = true;
    final cubit = buildCubit();
    cubit.start();

    papers.emitPaper(savedPaperWith(encryptedImagePath: '/enc/p1'));
    await pumpEventQueue();

    expect(states, hasLength(1));
    expect((states.single as PaperScreenReady).imageBytes, isNull);

    await cubit.close();
  });

  test(
    'a later re-emission of the same paper does not reload its image',
    () async {
      final bytes = Uint8List.fromList([9]);
      images.loadResult = bytes;
      final cubit = buildCubit();
      cubit.start();

      final paper = savedPaperWith(encryptedImagePath: '/enc/p1');
      papers.emitPaper(paper);
      await pumpEventQueue();
      papers.emitPaper(paper);
      await pumpEventQueue();

      expect(images.loadCallCount, 1);
      expect(states.last, isA<PaperScreenReady>());

      await cubit.close();
    },
  );

  test(
    'a new paper arriving mid-decrypt is the one carried by the result',
    () async {
      images.loadGate = Completer<void>();
      final cubit = buildCubit();
      cubit.start();

      papers.emitPaper(
        savedPaperWith(
          encryptedImagePath: '/enc/p1',
          savedAt: DateTime(2026, 11, 22, 9),
        ),
      );
      await pumpEventQueue();
      expect(images.loadCallCount, 1);

      final updated = savedPaperWith(
        encryptedImagePath: '/enc/p1',
        savedAt: DateTime(2026, 11, 22, 10),
      );
      papers.emitPaper(updated);
      await pumpEventQueue();

      expect(images.loadCallCount, 1);

      images.loadGate!.complete();
      await pumpEventQueue();

      final ready = states.last as PaperScreenReady;
      expect(ready.paper, updated);
      expect(ready.imageBytes, isNotNull);

      await cubit.close();
    },
  );

  test('the paper disappearing emits not found and clears the image', () async {
    images.loadResult = Uint8List.fromList([1]);
    final cubit = buildCubit();
    cubit.start();

    papers.emitPaper(savedPaperWith(encryptedImagePath: '/enc/p1'));
    await pumpEventQueue();

    papers.emitPaper(null);
    await pumpEventQueue();

    expect(states.last, const PaperScreenNotFound());

    await cubit.close();
  });

  test('a watch failure is reported as an error', () async {
    final cubit = buildCubit();
    cubit.start();

    papers.emitPaperFailure();
    await pumpEventQueue();

    expect(states, [const PaperScreenError(LocalDatabaseFailure())]);

    await cubit.close();
  });

  test('start is idempotent, so a second subscription never doubles up '
      'what the first one reports', () async {
    papers.emitPaper(savedPaperWith());
    final cubit = buildCubit();
    cubit.start();
    cubit.start();
    await pumpEventQueue();

    papers.emitPaper(savedPaperWith(savedAt: DateTime(2026, 11, 22, 10)));
    await pumpEventQueue();

    expect(states, hasLength(2));

    await cubit.close();
  });

  test('closing stops further emissions', () async {
    papers.emitPaper(savedPaperWith());
    final cubit = buildCubit();
    cubit.start();
    await pumpEventQueue();
    final beforeClose = List.of(states);
    await cubit.close();

    papers.emitPaper(savedPaperWith(savedAt: DateTime(2026, 11, 22, 10)));
    await pumpEventQueue();

    expect(states, beforeClose);
  });
}
