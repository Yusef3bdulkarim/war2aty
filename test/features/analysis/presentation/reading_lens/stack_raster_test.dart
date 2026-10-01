import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_layout.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/stack_raster.dart';

void main() {
  late StackRaster raster;

  setUp(() => raster = StackRaster());
  tearDown(() => raster.dispose());

  test('renders the stack once and reuses it', () {
    final first = raster.imageFor(AppColors.light, 2);
    expect(raster.imageFor(AppColors.light, 2), same(first));
    expect(first.debugDisposed, isFalse);
  });

  test('is sized to the paper and its margin, in physical pixels', () {
    final image = raster.imageFor(AppColors.light, 2);
    expect(image.width, ((PaperLayout.size.width + 2 * 72) * 2).ceil());
    expect(image.height, ((PaperLayout.size.height + 2 * 72) * 2).ceil());
  });

  test('renders again for a new palette or size, freeing the old one', () {
    final light = raster.imageFor(AppColors.light, 2);
    final contrast = raster.imageFor(AppColors.highContrast, 2);
    expect(contrast, isNot(same(light)));
    expect(light.debugDisposed, isTrue);

    final larger = raster.imageFor(AppColors.highContrast, 3);
    expect(larger, isNot(same(contrast)));
    expect(contrast.debugDisposed, isTrue);
  });

  test('cuts off nothing: the border of the image is transparent', () async {
    // If the margin were too small, a sheet or a shadow's blur would be
    // clipped at the image's edge and show as a hard line on screen.
    for (final colors in [AppColors.light, AppColors.highContrast]) {
      final image = raster.imageFor(colors, 1);
      final bytes = (await image.toByteData())!;
      int alphaAt(int x, int y) =>
          bytes.getUint8((y * image.width + x) * 4 + 3);
      for (var x = 0; x < image.width; x++) {
        expect(alphaAt(x, 0), 0, reason: 'top, x = $x');
        expect(alphaAt(x, image.height - 1), 0, reason: 'bottom, x = $x');
      }
      for (var y = 0; y < image.height; y++) {
        expect(alphaAt(0, y), 0, reason: 'left, y = $y');
        expect(alphaAt(image.width - 1, y), 0, reason: 'right, y = $y');
      }
    }
  });

  test('dispose frees the image', () {
    final image = raster.imageFor(AppColors.light, 1);
    raster.dispose();
    expect(image.debugDisposed, isTrue);
  });

  test('paints into a canvas', () {
    final recorder = ui.PictureRecorder();
    raster.paint(ui.Canvas(recorder), AppColors.light, 2);
    recorder.endRecording().dispose();
  });
}
