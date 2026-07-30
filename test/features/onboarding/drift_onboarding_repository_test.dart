import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/onboarding/data/repositories/drift_onboarding_repository.dart';

import '../../support/fakes.dart';

void main() {
  group('DriftOnboardingRepository', () {
    test('reports onboarding as unseen on a fresh install', () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      final repository = DriftOnboardingRepository(db);

      expect(
        await repository.hasSeenOnboarding(),
        const Ok<bool, AppFailure>(false),
      );
    });

    test('reports onboarding as seen once it has been marked', () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      final repository = DriftOnboardingRepository(db);

      expect(
        await repository.markOnboardingSeen(),
        isA<Ok<void, AppFailure>>(),
      );
      expect(
        await repository.hasSeenOnboarding(),
        const Ok<bool, AppFailure>(true),
      );
    });

    test(
      'the flag survives a new repository instance (same database)',
      () async {
        final db = memoryDatabase();
        addTearDown(db.close);

        await DriftOnboardingRepository(db).markOnboardingSeen();

        expect(
          await DriftOnboardingRepository(db).hasSeenOnboarding(),
          const Ok<bool, AppFailure>(true),
        );
      },
    );

    // The storage-failure branch (→ LocalDatabaseFailure) cannot be provoked
    // with an in-memory Drift database — it reopens transparently after
    // close(). The behaviour that depends on it is covered where it matters,
    // in onboarding_cubit_test ("falls back to showing onboarding …").
  });
}
