import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/onboarding_repository.dart';

/// Answers whether onboarding can be skipped on this launch.
final class HasSeenOnboarding {
  const HasSeenOnboarding(this._repository);

  final OnboardingRepository _repository;

  Future<Result<bool, AppFailure>> call() => _repository.hasSeenOnboarding();
}
