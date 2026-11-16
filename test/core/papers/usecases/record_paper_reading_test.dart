import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/usecases/record_paper_reading.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_outcome.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePapersRepository repository;
  late RecordPaperReading recordPaperReading;

  setUp(() {
    repository = FakePapersRepository();
    recordPaperReading = RecordPaperReading(repository);
  });

  test('passes the id and outcome straight to the repository', () async {
    final outcome = VoiceReadOutcome(
      engine: VoiceEngine.geminiLive,
      duration: const Duration(seconds: 75),
      verified: true,
      audioSaved: true,
      spans: const [],
    );

    await recordPaperReading(id: 'p1', outcome: outcome);

    expect(repository.lastRecordedId, 'p1');
    expect(repository.lastRecordedOutcome, same(outcome));
  });

  test('carries a failure straight through', () async {
    repository.recordReadingOutcome = const Err(LocalDatabaseFailure());

    final result = await recordPaperReading(
      id: 'p1',
      outcome: VoiceReadOutcome(
        engine: VoiceEngine.deviceTts,
        duration: const Duration(seconds: 10),
        verified: true,
        audioSaved: false,
        spans: const [],
      ),
    );

    expect(result, const Err<void, AppFailure>(LocalDatabaseFailure()));
  });
}
