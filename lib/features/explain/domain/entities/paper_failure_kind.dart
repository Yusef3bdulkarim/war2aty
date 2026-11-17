import '../../../../core/error/app_failure.dart';

enum PaperFailureKind {
  offline,
  limitReached,
  serviceProblem;

  static PaperFailureKind fromFailure(AppFailure failure) => switch (failure) {
    NoInternetFailure() => PaperFailureKind.offline,
    DailyLimitReachedFailure() => PaperFailureKind.limitReached,
    _ => PaperFailureKind.serviceProblem,
  };
}
