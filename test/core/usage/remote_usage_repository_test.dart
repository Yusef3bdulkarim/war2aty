import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/usage/daily_usage.dart';
import 'package:war2aty/core/usage/remote_usage_repository.dart';
import 'package:war2aty/core/usage/usage_remote_data_source.dart';

import '../../support/fakes.dart';

/// Mid-morning Cairo, so no test sits on a day boundary by accident.
final _now = DateTime.utc(2026, 7, 26, 9);

const _body = {
  'schema_version': '1.0',
  'usage_date': '2026-07-26',
  'daily_limit': 3,
  'used_today': 1,
  'remaining_today': 2,
  'resets_at': '2026-07-27T00:00:00+03:00',
  'analysis_enabled': true,
};

final class _FakeRemote implements UsageRemoteDataSource {
  _FakeRemote(this.respond);

  factory _FakeRemote.ok([Map<String, dynamic> body = _body]) =>
      _FakeRemote(() async => UsageApiResponse(statusCode: 200, body: body));

  factory _FakeRemote.offline() => _FakeRemote(
    () async => throw DioException(
      requestOptions: RequestOptions(path: '/get-usage'),
      type: DioExceptionType.connectionError,
    ),
  );

  final Future<UsageApiResponse> Function() respond;
  int calls = 0;

  @override
  Future<UsageApiResponse> fetchUsage() {
    calls += 1;
    return respond();
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  RemoteUsageRepository repository(UsageRemoteDataSource remote) =>
      RemoteUsageRepository(remote, db, clock: () => _now);

  group('syncUsage', () {
    test('returns the backend numbers and caches them', () async {
      final repo = repository(_FakeRemote.ok());

      final result = await repo.syncUsage();

      expect(result, isA<Ok<DailyUsage, AppFailure>>());
      final usage = result.valueOrNull!;
      expect(usage.dailyLimit, 3);
      expect(usage.usedCount, 1);
      expect(usage.remainingCount, 2);
      expect(usage.resetsAt, DateTime.utc(2026, 7, 26, 21));

      // Cached, so Home can answer instantly on the next launch.
      final cached = await repo.cachedUsage();
      expect(cached.valueOrNull!.usedCount, 1);
    });

    test('the Cairo day is stored as a UTC-midnight date', () async {
      // `DateTime.parse` on a bare date yields *local* midnight, which lands on
      // the previous day for any device east of UTC and mis-groups the row.
      final repo = repository(_FakeRemote.ok());

      final usage = (await repo.syncUsage()).valueOrNull!;

      expect(usage.usageDate, DateTime.utc(2026, 7, 26));
      expect(usage.usageDate.isUtc, isTrue);
    });

    test('offline falls back to the cached row rather than an error', () async {
      // A user on the metro should see this morning's "2 left", not a broken
      // counter. The real quota is enforced server-side, so a stale reading
      // cannot buy an extra analysis.
      await repository(_FakeRemote.ok()).syncUsage();

      final result = await repository(_FakeRemote.offline()).syncUsage();

      expect(result, isA<Ok<DailyUsage, AppFailure>>());
      expect(result.valueOrNull!.remainingCount, 2);
    });

    test('offline with nothing cached surfaces the network failure', () async {
      final result = await repository(_FakeRemote.offline()).syncUsage();

      expect(result, isA<Err<DailyUsage, AppFailure>>());
      // There is genuinely nothing to show, so inventing a full quota would be
      // a lie the user acts on.
      expect((result as Err).failure, isA<NoInternetFailure>());
    });

    test('a §31 error body maps through the shared mapper', () async {
      final repo = repository(
        _FakeRemote(
          () async => const UsageApiResponse(
            statusCode: 401,
            body: {
              'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
            },
          ),
        ),
      );

      final result = await repo.syncUsage();

      expect((result as Err).failure, isA<UnauthorizedFailure>());
    });

    test('an unreadable body is refused rather than half-parsed', () async {
      final repo = repository(
        _FakeRemote(
          () async => const UsageApiResponse(statusCode: 200, body: 'not json'),
        ),
      );

      expect(
        ((await repo.syncUsage()) as Err).failure,
        isA<InvalidAnalysisResponseFailure>(),
      );
    });

    test('a body missing a field is refused, not defaulted', () async {
      // A quota we cannot read is not a quota we can trust — defaulting to 3
      // would hand the user analyses the backend will refuse.
      final incomplete = Map<String, dynamic>.of(_body)..remove('daily_limit');
      final repo = repository(_FakeRemote.ok(incomplete));

      expect(
        ((await repo.syncUsage()) as Err).failure,
        isA<InvalidAnalysisResponseFailure>(),
      );
    });
  });

  group('cachedUsage', () {
    test('is null before anything has been synced', () async {
      final result = await repository(_FakeRemote.ok()).cachedUsage();

      // Missing state is a real answer, not an error.
      expect(result, isA<Ok<DailyUsage?, AppFailure>>());
      expect(result.valueOrNull, isNull);
    });

    test('never hits the network', () async {
      final remote = _FakeRemote.ok();

      await repository(remote).cachedUsage();

      expect(remote.calls, 0);
    });
  });

  group('watchUsage', () {
    test('reports no row before a sync, and the row after one', () async {
      final repo = repository(_FakeRemote.ok());

      // Awaited in sequence rather than collected with `take(2)`: subscription
      // is asynchronous, so a concurrent sync can land before the listener is
      // attached and the first emission is then already populated.
      expect((await repo.watchUsage().first).valueOrNull, isNull);

      await repo.syncUsage();

      expect((await repo.watchUsage().first).valueOrNull!.usedCount, 1);
    });
  });
}
