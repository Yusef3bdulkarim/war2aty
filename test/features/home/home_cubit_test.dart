import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/home/presentation/cubit/home_state.dart';

import '../../support/fakes.dart';

void main() {
  late FakeUsageRepository usage;
  late FakeRecentDocumentsRepository documents;
  late FakeUpcomingReminderRepository reminders;

  setUp(() {
    usage = FakeUsageRepository();
    documents = FakeRecentDocumentsRepository();
    reminders = FakeUpcomingReminderRepository();
  });
  tearDown(() async {
    await usage.dispose();
    await documents.dispose();
    await reminders.dispose();
  });

  HomeCubit buildCubit() => HomeCubit(
    watchDailyUsage: WatchDailyUsage(usage),
    watchRecentDocuments: WatchRecentDocuments(documents),
    watchUpcomingReminder: WatchUpcomingReminder(reminders),
  );

  group('HomeCubit', () {
    test('starts with nothing loaded', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.usage, const UsageLoading());
    });

    test('publishes the quota once the database answers', () async {
      final quota = usageWith(limit: 3, remaining: 2);
      usage.emit(quota);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      expect(cubit.state.usage, UsageAvailable(quota));
    });

    test('an empty cache is an answer, not a failure', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      expect(cubit.state.usage, const UsageAvailable(null));
    });

    test('follows later changes to the quota', () async {
      usage.emit(usageWith(limit: 3, remaining: 3));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      usage.emit(usageWith(limit: 3, remaining: 1));
      await pumpEventQueue();

      expect(
        cubit.state.usage,
        UsageAvailable(usageWith(limit: 3, remaining: 1)),
      );
    });

    test('surfaces a read failure instead of swallowing it', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      usage.emitFailure();
      await pumpEventQueue();

      expect(cubit.state.usage, const UsageUnavailable(LocalDatabaseFailure()));
    });

    test(
      'start is idempotent — a second call adds no second listener',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.start();
        cubit.start();
        await pumpEventQueue();

        // One listener per section, however often start() is called — a
        // second subscription would double every later emission and leak.
        expect(usage.listenCount, 1);
        expect(documents.listenCount, 1);
      },
    );

    test('publishes saved documents once they arrive', () async {
      final saved = [documentWith(id: 'a'), documentWith(id: 'b')];
      documents.emit(saved);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      expect(cubit.state.documents, DocumentsAvailable(saved));
    });

    test('an empty library is an answer, not a failure', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      expect(cubit.state.documents, const DocumentsAvailable([]));
    });

    test('asks for only as many documents as Home shows', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      // Home is a hub — the full list lives behind "see all".
      expect(documents.requestedLimit, WatchRecentDocuments.homeLimit);
    });

    test('a documents failure leaves the usage section alone', () async {
      usage.emit(usageWith(limit: 3, remaining: 2));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      documents.emitFailure();
      await pumpEventQueue();

      // One section failing must not blank the rest of the screen.
      expect(cubit.state.documents, isA<DocumentsUnavailable>());
      expect(
        cubit.state.usage,
        UsageAvailable(usageWith(limit: 3, remaining: 2)),
      );
    });

    test('publishes the next reminder once it arrives', () async {
      final reminder = reminderWith();
      reminders.emit(reminder);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      expect(cubit.state.reminder, ReminderAvailable(reminder));
    });

    test('nothing scheduled is an answer, not a failure', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      expect(cubit.state.reminder, const ReminderAvailable(null));
    });

    test('every section is watched exactly once', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      cubit.start();
      await pumpEventQueue();

      expect(usage.listenCount, 1);
      expect(documents.listenCount, 1);
      expect(reminders.listenCount, 1);
    });

    test('one section failing leaves the other two intact', () async {
      usage.emit(usageWith(limit: 3, remaining: 2));
      final saved = [documentWith()];
      documents.emit(saved);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.start();
      await pumpEventQueue();

      reminders.emitFailure();
      await pumpEventQueue();

      expect(cubit.state.reminder, isA<ReminderUnavailable>());
      expect(cubit.state.documents, DocumentsAvailable(saved));
      expect(
        cubit.state.usage,
        UsageAvailable(usageWith(limit: 3, remaining: 2)),
      );
    });

    test('emits nothing after close', () async {
      final cubit = buildCubit();
      cubit.start();
      await pumpEventQueue();
      await cubit.close();

      // Would throw if the subscription outlived the cubit.
      usage.emit(usageWith(limit: 3, remaining: 1));
      await pumpEventQueue();

      expect(cubit.isClosed, isTrue);
    });
  });
}
