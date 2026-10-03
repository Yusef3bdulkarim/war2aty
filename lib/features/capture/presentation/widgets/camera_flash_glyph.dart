import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_strings.dart';
import '../../domain/entities/camera_flash_mode.dart';

/// The icon for a flash mode — a different shape for each, so the mode never
/// rests on colour alone (F24).
StrokeGlyph glyphFor(CameraFlashMode mode) => switch (mode) {
  CameraFlashMode.off => StrokeGlyph.flashOff,
  CameraFlashMode.auto => StrokeGlyph.flashAuto,
  CameraFlashMode.on => StrokeGlyph.flash,
};

/// The flash mode in words: «الفلاش: مطفي / تلقائي / شغال».
String flashLabel(AppStrings strings, CameraFlashMode mode) => switch (mode) {
  CameraFlashMode.off => strings.cameraFlashOff,
  CameraFlashMode.auto => strings.cameraFlashAuto,
  CameraFlashMode.on => strings.cameraFlashOn,
};
