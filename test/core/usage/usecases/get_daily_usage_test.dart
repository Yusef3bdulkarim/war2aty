import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/usage/daily_usage.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';

import '../../../support/fakes.dart';

// F11-T12: settings' «حدود الاستخدام» row — a one-shot snapshot of today's
// cached quota, unlike `WatchDailyUsage`'s live stream.
void main() {
  test('answers null when nothing has been cached yet', () async {
    final useCase = GetDailyUsage(FakeUsageRepository());

    final result = await useCase();

    expect(result, const Ok<DailyUsage?, AppFailure>(null));
  });

  test('answers the cached quota', () async {
    final usage = usageWith(limit: 3, remaining: 1);
    final useCase = GetDailyUsage(FakeUsageRepository(seed: usage));

    final result = await useCase();

    expect(result, Ok<DailyUsage?, AppFailure>(usage));
  });

  test('surfaces a repository failure rather than swallowing it', () async {
    final repository = FakeUsageRepository()..emitFailure();
    final useCase = GetDailyUsage(repository);

    final result = await useCase();

    expect(result, const Err<DailyUsage?, AppFailure>(LocalDatabaseFailure()));
  });
}
