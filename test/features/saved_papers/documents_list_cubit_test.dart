import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/watch_documents.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/documents_list_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/documents_list_state.dart';

import '../../support/fakes.dart';

void main() {
  late FakeDocumentsRepository repository;

  setUp(() => repository = FakeDocumentsRepository());
  tearDown(() => repository.dispose());

  DocumentsListCubit buildCubit() =>
      DocumentsListCubit(WatchDocuments(repository));

  test('starts loading', () {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    expect(cubit.state, const DocumentsListLoading());
  });

  test('publishes the library once the database answers', () async {
    final saved = [documentWith(id: 'a'), documentWith(id: 'b')];
    repository.emit(saved);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state, DocumentsListAvailable(saved));
  });

  test('an empty library is an answer, not a failure', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state, const DocumentsListAvailable([]));
  });

  test('follows later changes to the library', () async {
    repository.emit([documentWith(id: 'a')]);
    final cubit = buildCubit();
    addTearDown(cubit.close);
    cubit.start();
    await pumpEventQueue();

    repository.emit([documentWith(id: 'a'), documentWith(id: 'b')]);
    await pumpEventQueue();

    expect(
      cubit.state,
      DocumentsListAvailable([documentWith(id: 'a'), documentWith(id: 'b')]),
    );
  });

  test('surfaces a read failure instead of swallowing it', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);
    cubit.start();
    await pumpEventQueue();

    repository.emitFailure();
    await pumpEventQueue();

    expect(cubit.state, const DocumentsListUnavailable(LocalDatabaseFailure()));
  });

  test('start is idempotent — a second call adds no second listener', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.start();
    cubit.start();
    await pumpEventQueue();

    // A second subscription would double every later emission and leak.
    expect(repository.listenCount, 1);
  });

  test('emits nothing after close', () async {
    final cubit = buildCubit();
    cubit.start();
    await pumpEventQueue();
    await cubit.close();

    // Would throw if the subscription outlived the cubit.
    repository.emit([documentWith()]);
    await pumpEventQueue();

    expect(cubit.isClosed, isTrue);
  });

  group('search', () {
    test('asks the repository for the typed title', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      cubit.search('كهرباء');
      await pumpEventQueue();

      expect(repository.requestedTitleQuery, 'كهرباء');
    });

    test('carries the active query on the resulting state', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      cubit.search('كهرباء');
      await pumpEventQueue();

      expect(cubit.state, const DocumentsListAvailable([], query: 'كهرباء'));
    });

    test('repeating the same query does not open a new subscription', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();
      cubit.search('كهرباء');
      await pumpEventQueue();
      final before = repository.listenCount;

      cubit.search('كهرباء');
      await pumpEventQueue();

      expect(repository.listenCount, before);
    });

    test('clearing the query asks the repository with a blank filter', () async {
      repository.emit([documentWith(id: 'a')]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();
      cubit.search('لا يوجد تطابق');
      await pumpEventQueue();

      cubit.search('');
      await pumpEventQueue();

      expect(repository.requestedTitleQuery, '');
      expect(cubit.state, DocumentsListAvailable([documentWith(id: 'a')]));
    });

    test('a later search cancels the earlier subscription', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      cubit.search('أ');
      await pumpEventQueue();
      cubit.search('أب');
      await pumpEventQueue();

      // Only the latest query's emission should still reach the state; an
      // emission from the abandoned subscription would overwrite it.
      repository.emit([documentWith(id: 'stale')]);
      await pumpEventQueue();

      expect(
        cubit.state,
        DocumentsListAvailable([documentWith(id: 'stale')], query: 'أب'),
      );
    });
  });
}
