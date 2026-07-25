import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';

void main() {
  group('OcrResult', () {
    test('equal when text and languages match', () {
      const a = OcrResult(
        originalText: 'hello',
        detectedLanguages: ['ar', 'en'],
      );
      const b = OcrResult(
        originalText: 'hello',
        detectedLanguages: ['ar', 'en'],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when text differs', () {
      const a = OcrResult(originalText: 'hello');
      const b = OcrResult(originalText: 'world');
      expect(a, isNot(equals(b)));
    });

    test('not equal when languages differ', () {
      const a = OcrResult(originalText: 'hello', detectedLanguages: ['ar']);
      const b = OcrResult(originalText: 'hello', detectedLanguages: ['en']);
      expect(a, isNot(equals(b)));
    });

    test('defaults to empty detected languages', () {
      const result = OcrResult(originalText: 'text');
      expect(result.detectedLanguages, isEmpty);
    });

    test('toString includes length and languages', () {
      const result = OcrResult(originalText: 'abc', detectedLanguages: ['ar']);
      expect(result.toString(), contains('3 chars'));
      expect(result.toString(), contains('ar'));
    });
  });
}
