/// Whether the first-run flow still has to be shown.
///
/// Sealed — the router's redirect must handle every case exhaustively.
sealed class OnboardingState {
  const OnboardingState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The stored flag has not been read yet; the app stays on the splash screen.
final class OnboardingUnknown extends OnboardingState {
  const OnboardingUnknown();
}

/// First run (or the flag could not be read) — show onboarding.
final class OnboardingRequired extends OnboardingState {
  const OnboardingRequired();
}

/// Already seen — go straight to Home.
final class OnboardingCompleted extends OnboardingState {
  const OnboardingCompleted();
}
