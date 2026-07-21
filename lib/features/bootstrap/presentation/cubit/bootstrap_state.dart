import '../../../../core/error/app_failure.dart';
import '../../domain/entities/bootstrap_stage.dart';

/// UI state of the launch sequence. Sealed — the splash must handle every case.
sealed class BootstrapState {
  const BootstrapState();
}

/// Nothing has started yet.
final class BootstrapInitial extends BootstrapState {
  const BootstrapInitial();

  @override
  bool operator ==(Object other) => other is BootstrapInitial;

  @override
  int get hashCode => (BootstrapInitial).hashCode;
}

/// Launch is running; [stage] is the step in flight (null before the first).
final class BootstrapInProgress extends BootstrapState {
  const BootstrapInProgress([this.stage]);

  final BootstrapStage? stage;

  @override
  bool operator ==(Object other) =>
      other is BootstrapInProgress && other.stage == stage;

  @override
  int get hashCode => Object.hash(BootstrapInProgress, stage);
}

/// Launch finished; the app can show its shell.
final class BootstrapSuccess extends BootstrapState {
  const BootstrapSuccess();

  @override
  bool operator ==(Object other) => other is BootstrapSuccess;

  @override
  int get hashCode => (BootstrapSuccess).hashCode;
}

/// Launch stopped on a critical [failure]; the user is offered a retry.
final class BootstrapFailure extends BootstrapState {
  const BootstrapFailure(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BootstrapFailure && other.failure == failure;

  @override
  int get hashCode => Object.hash(BootstrapFailure, failure);
}
