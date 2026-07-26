/// Where camera access stands for the capture flow.
///
/// Sealed so the gate screen must handle every case — there is no "unknown UI"
/// branch to forget.
sealed class CameraPermissionState {
  const CameraPermissionState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Reading the OS state. Nothing is drawn yet — this is a frame or two, and
/// flashing the explanation sheet at a user who already said yes is worse than
/// a blank moment.
final class CameraPermissionChecking extends CameraPermissionState {
  const CameraPermissionChecking();
}

/// The camera may be used; the capture screen takes over.
final class CameraPermissionGranted extends CameraPermissionState {
  const CameraPermissionGranted();
}

/// Not granted, but asking again will still show the system prompt — so the
/// sheet explains why, and its button fires that prompt.
final class CameraPermissionDenied extends CameraPermissionState {
  const CameraPermissionDenied();
}

/// The OS will not prompt again. The same sheet stays, with copy and a button
/// that point at the settings app instead.
final class CameraPermissionBlocked extends CameraPermissionState {
  const CameraPermissionBlocked();
}
