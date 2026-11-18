sealed class PaperFailureState {
  const PaperFailureState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PaperFailureReady extends PaperFailureState {
  const PaperFailureReady();
}
