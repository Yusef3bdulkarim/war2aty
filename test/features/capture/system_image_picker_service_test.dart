import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/data/services/system_image_picker_service.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';

/// Records the [ImagePickerOptions] it was asked to pick with, so the
/// resize cap in [SystemImagePickerService] can be asserted without a real
/// device or gallery.
class _RecordingImagePickerPlatform extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  ImagePickerOptions? lastOptions;
  XFile? nextResult;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    lastOptions = options;
    return nextResult;
  }
}

void main() {
  late _RecordingImagePickerPlatform platform;
  late SystemImagePickerService service;

  setUp(() {
    platform = _RecordingImagePickerPlatform();
    ImagePickerPlatform.instance = platform;
    service = SystemImagePickerService(ImagePicker());
  });

  test('caps a picked photo to the same ceiling OCR resizes down to, so a '
      'full-resolution gallery photo is never decoded just to be shrunk right '
      'back down on the next screen', () async {
    await service.pickSingleImage();

    expect(platform.lastOptions?.maxWidth, 4096);
    expect(platform.lastOptions?.maxHeight, 4096);
  });

  test('returns the picked photo', () async {
    platform.nextResult = XFile('/tmp/picked.jpg');

    final result = await service.pickSingleImage();

    expect(
      result,
      const Ok<CapturedPhoto?, AppFailure>(CapturedPhoto('/tmp/picked.jpg')),
    );
  });

  test('a cancelled pick is Ok(null), not a failure', () async {
    platform.nextResult = null;

    final result = await service.pickSingleImage();

    expect(result, const Ok<CapturedPhoto?, AppFailure>(null));
  });
}
