import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/capture_source.dart';

void main() {
  group('CaptureSource.parse', () {
    test('reads the two sources back from their route value', () {
      expect(CaptureSource.parse('camera'), CaptureSource.camera);
      expect(CaptureSource.parse('gallery'), CaptureSource.gallery);
    });

    test('falls back to the camera rather than throwing', () {
      // A stale link or a missing query parameter must still open something.
      expect(CaptureSource.parse(null), CaptureSource.camera);
      expect(CaptureSource.parse(''), CaptureSource.camera);
      expect(CaptureSource.parse('scanner'), CaptureSource.camera);
    });
  });
}
