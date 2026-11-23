sealed class PhoneDialerState {
  const PhoneDialerState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PhoneDialerIdle extends PhoneDialerState {
  const PhoneDialerIdle();
}

final class PhoneDialerCallFailed extends PhoneDialerState {
  const PhoneDialerCallFailed();
}
