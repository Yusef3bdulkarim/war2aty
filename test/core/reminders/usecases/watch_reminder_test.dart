import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminder.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeRemindersRepository repository;
  late WatchReminder useCase;

  setUp(() {
    repository = FakeRemindersRepository();
    useCase = WatchReminder(repository);
  });
  tearDown(() => repository.dispose());

  test('streams the repository\'s answer for the given id', () async {
    final reminder = fakeReminder();
    repository.emitReminder('r1', reminder);

    final result = await useCase('r1').first;

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, reminder);
  });

  test('streams null when there is no such reminder', () async {
    final result = await useCase('missing').first;

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isNull);
  });

  test('a later emit for the same id reaches an existing subscriber', () async {
    final stream = useCase('r1');
    final results = <Object?>[];
    final subscription = stream.listen(results.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    repository.emitReminder('r1', fakeReminder());
    await pumpEventQueue();

    expect(results, hasLength(2));
  });
}
