import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/usecases/load_paper_image.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePaperImageStore store;
  late LoadPaperImage loadPaperImage;

  setUp(() {
    store = FakePaperImageStore();
    loadPaperImage = LoadPaperImage(store);
  });

  test('returns the stored image bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    store.loadResult = bytes;

    final result = await loadPaperImage('p1');

    expect((result as Ok<Uint8List, AppFailure>).value, bytes);
  });

  test('surfaces a store failure', () async {
    store.fails = true;

    final result = await loadPaperImage('p1');

    expect(result, const Err<Uint8List, AppFailure>(FileStorageFailure()));
  });
}
