import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:war2aty/features/ocr/data/services/dart_image_preprocessor.dart';

void main() {
  group('DartImagePreprocessor resize logic', () {
    Uint8List makeJpeg(int width, int height) {
      final image = img.Image(width: width, height: height);
      return img.encodeJpg(image);
    }

    test('returns null when image is within bounds', () {
      final bytes = makeJpeg(2000, 1500);
      final result = DartImagePreprocessor.resizeIfNeeded(
        bytes,
        kMaxOcrDimension,
      );
      expect(result, isNull);
    });

    test('resizes when width exceeds max dimension', () {
      final bytes = makeJpeg(5000, 3000);
      final result = DartImagePreprocessor.resizeIfNeeded(
        bytes,
        kMaxOcrDimension,
      );
      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(kMaxOcrDimension));
      expect(decoded.height, lessThanOrEqualTo(kMaxOcrDimension));
    });

    test('resizes when height exceeds max dimension', () {
      final bytes = makeJpeg(3000, 5000);
      final result = DartImagePreprocessor.resizeIfNeeded(
        bytes,
        kMaxOcrDimension,
      );
      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.height, equals(kMaxOcrDimension));
      expect(decoded.width, lessThanOrEqualTo(kMaxOcrDimension));
    });

    test('resizes when both dimensions exceed max', () {
      final bytes = makeJpeg(6000, 5000);
      final result = DartImagePreprocessor.resizeIfNeeded(
        bytes,
        kMaxOcrDimension,
      );
      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(kMaxOcrDimension));
      expect(decoded.height, lessThanOrEqualTo(kMaxOcrDimension));
    });

    test('returns null when exactly at max dimension', () {
      final bytes = makeJpeg(kMaxOcrDimension, kMaxOcrDimension);
      final result = DartImagePreprocessor.resizeIfNeeded(
        bytes,
        kMaxOcrDimension,
      );
      expect(result, isNull);
    });

    test('returns null for undecodable bytes', () {
      final garbage = Uint8List.fromList([0, 1, 2, 3, 4]);
      final result = DartImagePreprocessor.resizeIfNeeded(
        garbage,
        kMaxOcrDimension,
      );
      expect(result, isNull);
    });
  });
}
