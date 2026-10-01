import 'dart:ui' as ui;

import '../../../../../core/theme/app_colors.dart';
import 'paper_layout.dart';
import 'paper_painting.dart';

/// The sheet stack behind the paper — two tilted sheets, the paper, and their
/// blurred shadows — rendered once into pixels and reused on every frame
/// (F22-T13).
///
/// The stack never changes while the lens reads; it only floats. Drawing it
/// each frame meant blurring three shadows each frame, and a
/// `RepaintBoundary` would not avoid that: it saves re-recording the
/// drawing, but Impeller has no raster cache, so the blurs would still be
/// rendered every frame. An image is blurred once.
///
/// Rendered again only when the palette or the on-screen size changes. The
/// owner disposes it.
final class StackRaster {
  ui.Image? _image;
  AppColors? _colors;
  double _scale = 0;

  /// Room around the paper for the tilted sheets and the shadows' blur: the
  /// paper's own shadow reaches about 63 below it.
  static const double margin = 72;

  /// What the image covers, in paper units.
  static final ui.Rect bounds = ui.Rect.fromLTRB(
    -margin,
    -margin,
    PaperLayout.size.width + margin,
    PaperLayout.size.height + margin,
  );

  /// The stack in [colors], with [scale] physical pixels per paper unit.
  ui.Image imageFor(AppColors colors, double scale) {
    final cached = _image;
    if (cached != null && colors == _colors && scale == _scale) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..scale(scale)
      ..translate(margin, margin);
    PaperPainting.paintStack(canvas, colors);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (bounds.width * scale).ceil(),
      (bounds.height * scale).ceil(),
    );
    picture.dispose();

    cached?.dispose();
    _image = image;
    _colors = colors;
    _scale = scale;
    return image;
  }

  /// Draws the stack in paper units, at [scale] physical pixels per unit.
  void paint(ui.Canvas canvas, AppColors colors, double scale) {
    final image = imageFor(colors, scale);
    canvas.drawImageRect(
      image,
      ui.Offset.zero & ui.Size(image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(
        bounds.left,
        bounds.top,
        image.width / scale,
        image.height / scale,
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  void dispose() {
    _image?.dispose();
    _image = null;
  }
}
