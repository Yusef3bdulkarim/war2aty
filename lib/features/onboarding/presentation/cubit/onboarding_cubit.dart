import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/complete_onboarding.dart';
import '../../domain/usecases/has_seen_onboarding.dart';
import 'onboarding_state.dart';

/// Owns the first-run gate: reads the persisted flag once at launch, and flips
/// it when the user finishes the privacy step.
///
/// App-scoped (a single instance) because the router's redirect reads this
/// state. Depends on use cases only — no repository, no BuildContext.
final class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required HasSeenOnboarding hasSeenOnboarding,
    required CompleteOnboarding completeOnboarding,
  }) : _hasSeenOnboarding = hasSeenOnboarding,
       _completeOnboarding = completeOnboarding,
       super(const OnboardingUnknown());

  final HasSeenOnboarding _hasSeenOnboarding;
  final CompleteOnboarding _completeOnboarding;

  /// Resolves the gate. Idempotent: once resolved, re-calling is a no-op, so
  /// it is safe to trigger from a widget that may rebuild.
  Future<void> load() async {
    if (state is! OnboardingUnknown || isClosed) return;

    final result = await _hasSeenOnboarding();
    if (isClosed) return;

    // A storage failure falls back to showing onboarding: seeing the privacy
    // explanation one extra time is the safe side of this error.
    emit(
      result.when(
        ok: (seen) =>
            seen ? const OnboardingCompleted() : const OnboardingRequired(),
        err: (_) => const OnboardingRequired(),
      ),
    );
  }

  /// Finishes onboarding and lets the user through to Home.
  ///
  /// The user is never blocked on a storage failure — the gate opens either
  /// way; the worst case is that onboarding is shown again next launch.
  Future<void> complete() async {
    if (isClosed) return;
    await _completeOnboarding();
    if (isClosed) return;
    emit(const OnboardingCompleted());
  }
}
