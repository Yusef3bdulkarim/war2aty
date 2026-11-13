import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/data/services/encrypted_m4a_audio_source.dart';

void main() {
  final sampleData = Uint8List.fromList(List.generate(100, (i) => i % 256));

  group('EncryptedM4aAudioSource', () {
    test('full request returns all bytes', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request();

      final bytes = await _collectBytes(response.stream);
      expect(bytes, sampleData);
    });

    test('full request has correct metadata', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request();

      expect(response.sourceLength, 100);
      expect(response.contentLength, 100);
      expect(response.offset, 0);
      expect(response.contentType, 'audio/mp4');
    });

    test('range request with start only returns from start to end', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request(50);

      final bytes = await _collectBytes(response.stream);
      expect(bytes, sampleData.sublist(50));
      expect(response.sourceLength, 100);
      expect(response.contentLength, 50);
      expect(response.offset, 50);
    });

    test('range request with start and end returns the slice', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request(10, 30);

      final bytes = await _collectBytes(response.stream);
      expect(bytes, sampleData.sublist(10, 30));
      expect(response.sourceLength, 100);
      expect(response.contentLength, 20);
      expect(response.offset, 10);
    });

    test('content type is audio/mp4', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request();

      expect(response.contentType, 'audio/mp4');
    });

    test('length getter matches buffer length', () {
      final source = EncryptedM4aAudioSource(sampleData);
      expect(source.length, 100);
    });

    test('empty buffer produces a zero-length response', () async {
      final source = EncryptedM4aAudioSource(Uint8List(0));
      final response = await source.request();

      final bytes = await _collectBytes(response.stream);
      expect(bytes, isEmpty);
      expect(response.sourceLength, 0);
      expect(response.contentLength, 0);
      expect(response.offset, 0);
    });

    test('single-byte buffer round-trips', () async {
      final source = EncryptedM4aAudioSource(Uint8List.fromList([42]));
      final response = await source.request();

      final bytes = await _collectBytes(response.stream);
      expect(bytes, [42]);
      expect(response.sourceLength, 1);
      expect(response.contentLength, 1);
    });

    test('zero-length range returns empty bytes', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request(50, 50);

      final bytes = await _collectBytes(response.stream);
      expect(bytes, isEmpty);
      expect(response.contentLength, 0);
      expect(response.offset, 50);
    });

    test('stream delivers bytes in a single event', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request(0, 20);

      int eventCount = 0;
      await response.stream.forEach((_) => eventCount++);
      expect(eventCount, 1);
    });

    test('multiple sequential requests are independent', () async {
      final source = EncryptedM4aAudioSource(sampleData);

      final r1 = await source.request(0, 10);
      final r2 = await source.request(90, 100);

      final b1 = await _collectBytes(r1.stream);
      final b2 = await _collectBytes(r2.stream);

      expect(b1, sampleData.sublist(0, 10));
      expect(b2, sampleData.sublist(90, 100));
    });

    test('request at the end of buffer returns remaining bytes', () async {
      final source = EncryptedM4aAudioSource(sampleData);
      final response = await source.request(95);

      final bytes = await _collectBytes(response.stream);
      expect(bytes, sampleData.sublist(95));
      expect(response.contentLength, 5);
    });

    test('a 0.3 MB buffer serves seek correctly', () async {
      final big = Uint8List(300 * 1024);
      for (var i = 0; i < big.length; i++) {
        big[i] = i % 256;
      }

      final source = EncryptedM4aAudioSource(big);

      final fullResp = await source.request();
      expect(fullResp.sourceLength, big.length);
      expect(fullResp.contentLength, big.length);

      final midStart = big.length ~/ 2;
      final midResp = await source.request(midStart, midStart + 1024);
      final midBytes = await _collectBytes(midResp.stream);
      expect(midBytes, big.sublist(midStart, midStart + 1024));
    });
  });
}

Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
  final chunks = await stream.toList();
  return chunks.expand((c) => c).toList();
}
