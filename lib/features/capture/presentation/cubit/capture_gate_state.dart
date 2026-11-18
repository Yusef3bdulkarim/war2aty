import '../../domain/entities/capture_source.dart';

sealed class CaptureGateState {
  const CaptureGateState();
}

final class CaptureGateIdle extends CaptureGateState {
  const CaptureGateIdle();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class CaptureGateOpen extends CaptureGateState {
  const CaptureGateOpen(this.source);

  final CaptureSource source;

  @override
  bool operator ==(Object other) =>
      other is CaptureGateOpen && other.source == source;

  @override
  int get hashCode => source.hashCode;
}

final class CaptureGateOffline extends CaptureGateState {
  const CaptureGateOffline();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class CaptureGateServiceOff extends CaptureGateState {
  const CaptureGateServiceOff();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
