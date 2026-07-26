import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/onboarding_repository.dart';

/// Marks onboarding as finished so later launches go straight to Home.
final class CompleteOnboarding {
  const CompleteOnboarding(this._repository);

  final OnboardingRepository _repository;

  Future<Result<void, AppFailure>> call() => _repository.markOnboardingSeen();
}
