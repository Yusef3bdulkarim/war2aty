import 'package:flutter/widgets.dart';

/// The UI port for the live camera feed.
///
/// A running preview is irreducibly a Flutter widget bound to the platform
/// camera, so the viewfinder screen needs *some* way to render it. Rather than
/// let that pull the plugin up into the UI, the presentation layer declares the
/// exact capability it needs here, and the data-layer camera implementation
/// satisfies it (dependency inversion). The screen depends only on this port;
/// the plugin stays confined to the implementation, and tests supply a fake
/// that paints a plain placeholder.
abstract interface class CameraPreviewPort {
  /// Builds the live preview. Only valid once the camera is initialized;
  /// before that the screen shows its own loading state instead.
  Widget build(BuildContext context);
}
