import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_state.dart';

import '../../support/fakes.dart';

void main() {
  OnboardingCubit cubitFor(FakeOnboardingRepository repository) =>
      OnboardingCubit(
        hasSeenOnboarding: HasSeenOnboarding(repository),
        completeOnboarding: CompleteOnboarding(repository),
      );

  group('OnboardingCubit', () {
    test('starts unresolved', () {
      final cubit = cubitFor(FakeOnboardingRepository());
      addTearDown(cubit.close);

      expect(cubit.state, const OnboardingUnknown());
    });

    test('requires onboarding on a first run', () async {
      final cubit = cubitFor(FakeOnboardingRepository());
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, const OnboardingRequired());
    });

    test('skips onboarding when the flag is already set', () async {
      final cubit = cubitFor(FakeOnboardingRepository(seen: true));
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, const OnboardingCompleted());
    });

    test(
      'falls back to showing onboarding when the flag cannot be read',
      () async {
        final cubit = cubitFor(FakeOnboardingRepository(fails: true));
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state, const OnboardingRequired());
      },
    );

    test('load is idempotent — a second call does not re-emit', () async {
      final cubit = cubitFor(FakeOnboardingRepository());
      addTearDown(cubit.close);
      final emitted = <OnboardingState>[];
      cubit.stream.listen(emitted.add);

      await cubit.load();
      await cubit.load();
      await pumpEventQueue();

      expect(emitted, const [OnboardingRequired()]);
    });

    test('complete persists the flag and opens the gate', () async {
      final repository = FakeOnboardingRepository();
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.complete();

      expect(cubit.state, const OnboardingCompleted());
      expect(repository.seen, isTrue);
    });

    test('complete still opens the gate when persisting fails', () async {
      final cubit = cubitFor(FakeOnboardingRepository(fails: true));
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.complete();

      expect(cubit.state, const OnboardingCompleted());
    });
  });
}
