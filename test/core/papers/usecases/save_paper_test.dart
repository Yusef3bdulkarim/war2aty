import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/explain_outcome.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/usecases/save_paper.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePapersRepository repository;
  late FakePaperImageStore images;
  late SavePaper savePaper;

  setUp(() {
    repository = FakePapersRepository();
    images = FakePaperImageStore();
    savePaper = SavePaper(repository, images, idGenerator: () => 'p1');
  });

  test('writes the row under the id handed to the image store', () async {
    final result = await savePaper(
      outcome: _outcome(),
      photographedAt: DateTime(2026, 11, 16, 9),
      imagePath: '/tmp/photo.jpg',
    );

    expect(repository.lastInsertedId, 'p1');
    expect((result as Ok<SavePaperOutcome, AppFailure>).value.id, 'p1');
  });

  test('encrypts the photo and reports it saved', () async {
    final result = await savePaper(
      outcome: _outcome(),
      photographedAt: DateTime(2026, 11, 16, 9),
      imagePath: '/tmp/photo.jpg',
    );

    expect(images.stored['p1'], '/tmp/photo.jpg');
    expect(
      repository.lastEncryptedImagePath,
      '/private/paper_images/p1/image.enc',
    );
    expect(
      (result as Ok<SavePaperOutcome, AppFailure>).value.imageSaved,
      isTrue,
    );
  });

  test(
    'still saves the row when image encryption fails, reporting the loss',
    () async {
      images.fails = true;

      final result = await savePaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
        imagePath: '/tmp/photo.jpg',
      );

      expect(repository.lastInsertedId, 'p1');
      expect(repository.lastEncryptedImagePath, isNull);
      expect(
        (result as Ok<SavePaperOutcome, AppFailure>).value.imageSaved,
        isFalse,
      );
    },
  );

  test('deletes the orphaned image when the row write fails', () async {
    repository.insertOutcome = const Err(LocalDatabaseFailure());

    final result = await savePaper(
      outcome: _outcome(),
      photographedAt: DateTime(2026, 11, 16, 9),
      imagePath: '/tmp/photo.jpg',
    );

    expect(
      result,
      const Err<SavePaperOutcome, AppFailure>(LocalDatabaseFailure()),
    );
    expect(images.deletedIds, ['p1']);
  });

  test('passes the outcome and photographedAt straight through', () async {
    final outcome = _outcome();
    final photographedAt = DateTime(2026, 11, 16, 9);

    await savePaper(
      outcome: outcome,
      photographedAt: photographedAt,
      imagePath: '/tmp/photo.jpg',
    );

    expect(repository.lastInsertedOutcome, outcome);
    expect(repository.lastPhotographedAt, photographedAt);
  });
}

ExplainOutcome _outcome() => (
  explanation: PaperExplanation(
    title: 'فاتورة كهرباء',
    status: PaperStatus.success,
    paragraphs: const ['الفقرة الأولى.'],
    todo: const PaperTodo(required: true, text: 'روح لأقرب فرع'),
  ),
  sessionId: 'session-1',
  explainSchemaVersion: '1.0',
);
