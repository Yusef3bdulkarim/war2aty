// Finishes the Play Store graphics (F27-T21): builds the 512 px icon, and
// puts every other image into the pixel format Play accepts.
//
//   flutter test test/store/generate_store_assets.dart --update-goldens
//   dart run tool/store/finalize_store_assets.dart
//
// In that order: the first renders the feature graphic and the screenshots,
// this one finishes them. Play's formats differ by field, and neither of the
// renderers produces the right one on its own:
//
// - **Icon**: a 32-bit PNG. The `image` package would write the opaque
//   composite as 24-bit RGB, so an alpha channel is added — fully opaque.
// - **Feature graphic and screenshots**: JPEG or **24-bit PNG, no alpha**.
//   Flutter's golden renderer always writes RGBA, so the alpha channel is
//   dropped — after checking that no pixel actually used it, because a
//   transparent pixel flattened to RGB silently turns black.
//
// Re-running it is safe: an image already in its final format passes through
// unchanged.
//
// ## The icon
//
// Why it is not `assets/app_icon.png`, which is already 512 px: that file has
// **rounded, transparent corners**, because it is the in-app mark. Play applies
// its own rounded mask to whatever you upload, so a pre-rounded icon is rounded
// twice — visibly, as a dark seam inside the corner — and a transparent corner
// shows whatever is behind it in the store's own layout.
//
// Why the layers are cropped rather than scaled: an adaptive icon is drawn on a
// 108 dp canvas of which Android shows only the middle **72 dp**; the outer ring
// exists for parallax and masking. Compositing the two 432 px layers whole would
// produce an icon whose mark is a third smaller than the one on the launcher.
// Cropping to the centre 288 px (432 × 72/108) first is what makes the store
// icon and the launcher icon the same picture.
//
// Output: `store/icon-512.png`, square, fully opaque, 32-bit RGBA.
import 'dart:io';

import 'package:image/image.dart' as img;

/// The adaptive-icon layers, at the highest density the project ships.
const String _layerDirectory = 'android/app/src/main/res/mipmap-xxxhdpi';

/// Android's adaptive-icon geometry: a 108 dp canvas, 72 dp of it visible.
const double _visibleFraction = 72 / 108;

/// Play's required icon size.
const int _iconSize = 512;

void main() {
  _buildIcon();
  _flattenRenders();
}

void _buildIcon() {
  // Both layers come from the brand generator
  // (`dart run tool/branding/generate_brand_assets.dart`).
  final background = _read('$_layerDirectory/ic_launcher_background.png');
  final foreground = _read('$_layerDirectory/ic_launcher_foreground.png');

  if (background.width != foreground.width ||
      background.height != foreground.height) {
    stderr.writeln(
      'The two layers are different sizes (${background.width}x'
      '${background.height} vs ${foreground.width}x${foreground.height}); '
      'the crop below assumes one canvas.',
    );
    exit(1);
  }

  final canvas = background.width;
  final visible = (canvas * _visibleFraction).round();
  final inset = ((canvas - visible) / 2).round();

  img.Image crop(img.Image layer) =>
      img.copyCrop(layer, x: inset, y: inset, width: visible, height: visible);

  // Composited at the layers' own resolution and scaled once at the end:
  // scaling each layer first would resample the mark twice.
  final composed = img.compositeImage(crop(background), crop(foreground));
  final icon = img.copyResize(
    composed,
    width: _iconSize,
    height: _iconSize,
    interpolation: img.Interpolation.cubic,
  );

  // Play's field takes a 32-bit PNG, and a transparent pixel in it would show
  // the store's own background through the icon. The background layer is
  // already opaque, so this is a guarantee rather than a repair — and it
  // fails loudly if that ever stops being true.
  final transparent = _firstTransparentPixel(icon);
  if (transparent != null) {
    stderr.writeln(
      'Pixel $transparent is not opaque. The store icon must be a full '
      'square: Play masks the corners itself.',
    );
    exit(1);
  }

  Directory('store').createSync(recursive: true);
  _write('store/icon-512.png', icon.convert(numChannels: 4));
}

/// The images Flutter rendered, which Play takes only as 24-bit (no alpha).
void _flattenRenders() {
  final renders = [
    File('store/feature-graphic.png'),
    ...Directory('store/screenshots')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.png')),
  ];

  for (final file in renders) {
    if (!file.existsSync()) {
      stderr.writeln(
        '${file.path} does not exist. Render it first: flutter test '
        'test/store/generate_store_assets.dart --update-goldens',
      );
      exit(66);
    }
    final image = _read(file.path);

    final transparent = _firstTransparentPixel(image);
    if (transparent != null) {
      stderr.writeln(
        '${file.path}: pixel $transparent is not opaque. Dropping the alpha '
        'channel would turn it black — fix the render, not this step.',
      );
      exit(1);
    }
    _write(file.path, image.convert(numChannels: 3));
  }
}

void _write(String path, img.Image image) {
  final out = File(path)..writeAsBytesSync(img.encodePng(image, level: 9));
  stdout.writeln(
    '${path.padRight(40)} ${image.width}x${image.height}  '
    '${image.numChannels == 4 ? 'RGBA' : 'RGB '}  '
    '${(out.lengthSync() / 1024).toStringAsFixed(1)} KB',
  );
}

img.Image _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('$path does not exist.');
    exit(66);
  }
  final decoded = img.decodePng(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('$path is not a readable PNG.');
    exit(1);
  }
  return decoded;
}

/// The first `(x, y)` whose alpha is below full, or null when all are opaque.
String? _firstTransparentPixel(img.Image image) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a < 255) return '($x, $y)';
    }
  }
  return null;
}
