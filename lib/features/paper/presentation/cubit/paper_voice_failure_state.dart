sealed class PaperVoiceFailureState {
  const PaperVoiceFailureState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PaperVoiceFailureReady extends PaperVoiceFailureState {
  const PaperVoiceFailureReady();
}
