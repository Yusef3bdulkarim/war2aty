import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/core/database/daos/papers_dao.dart';
import 'package:war2aty/core/env/app_environment.dart';
import 'package:war2aty/core/papers/build_paper_voice_segments.dart';
import 'package:war2aty/core/papers/paper_image_store.dart';
import 'package:war2aty/core/papers/papers_repository.dart';
import 'package:war2aty/core/papers/usecases/delete_all_papers.dart';
import 'package:war2aty/core/papers/usecases/delete_paper.dart';
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/papers/usecases/record_paper_reading.dart';
import 'package:war2aty/core/papers/usecases/save_paper.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/papers/usecases/watch_papers.dart';
import 'package:war2aty/features/explain/data/datasources/explain_remote_data_source.dart';
import 'package:war2aty/features/explain/domain/repositories/explain_repository.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_paper.dart';

import '../support/fakes.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(
      AppEnvironment.dev(),
      database: memoryDatabase(),
    );
  });

  tearDown(getIt.reset);

  group('papers', () {
    test('the dao resolves off the shared database', () {
      expect(getIt<PapersDao>(), isA<PapersDao>());
    });

    test('the image store resolves without touching the filesystem', () {
      expect(getIt<PaperImageStore>(), isA<PaperImageStore>());
    });

    test('the repository resolves over the dao, the images and the audio', () {
      expect(getIt<PapersRepository>(), isA<PapersRepository>());
    });

    test('every use case resolves', () {
      expect(getIt<SavePaper>(), isA<SavePaper>());
      expect(getIt<RecordPaperReading>(), isA<RecordPaperReading>());
      expect(getIt<WatchPapers>(), isA<WatchPapers>());
      expect(getIt<WatchPaper>(), isA<WatchPaper>());
      expect(getIt<DeletePaper>(), isA<DeletePaper>());
      expect(getIt<DeleteAllPapers>(), isA<DeleteAllPapers>());
      expect(getIt<LoadPaperImage>(), isA<LoadPaperImage>());
    });

    test('the card-to-voice mapper resolves', () {
      expect(getIt<BuildPaperVoiceSegments>(), isA<BuildPaperVoiceSegments>());
    });
  });

  group('explain', () {
    test('the datasource resolves off the shared Dio', () {
      expect(getIt<ExplainRemoteDataSource>(), isA<ExplainRemoteDataSource>());
    });

    test('the repository and the use case resolve', () {
      expect(getIt<ExplainRepository>(), isA<ExplainRepository>());
      expect(getIt<ExplainPaper>(), isA<ExplainPaper>());
    });
  });
}
