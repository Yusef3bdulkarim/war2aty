import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';

/// Remembers whether the first-run onboarding has already been shown.
///
/// The flag lives on the device only — it is never synced, and it carries no
/// user data.
abstract interface class OnboardingRepository {
  /// Whether the user has already completed onboarding.
  Future<Result<bool, AppFailure>> hasSeenOnboarding();

  /// Records that onboarding was completed, so it is never shown again.
  Future<Result<void, AppFailure>> markOnboardingSeen();
}
