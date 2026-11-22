import '../../domain/entities/paper_failure_kind.dart';

sealed class PaperWaitingState {
  const PaperWaitingState();
}

final class PaperWaitingInProgress extends PaperWaitingState {
  const PaperWaitingInProgress();

  @override
  bool operator ==(Object other) => other is PaperWaitingInProgress;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PaperWaitingNavigateToPaper extends PaperWaitingState {
  const PaperWaitingNavigateToPaper(this.paperId);

  final String paperId;

  @override
  bool operator ==(Object other) =>
      other is PaperWaitingNavigateToPaper && other.paperId == paperId;

  @override
  int get hashCode => Object.hash(runtimeType, paperId);
}

final class PaperWaitingFailed extends PaperWaitingState {
  const PaperWaitingFailed(this.kind);

  final PaperFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is PaperWaitingFailed && other.kind == kind;

  @override
  int get hashCode => Object.hash(runtimeType, kind);
}
