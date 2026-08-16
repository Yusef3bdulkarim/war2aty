import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/accessibility/text_size.dart';
import 'package:war2aty/core/accessibility/text_size_cubit.dart';
import 'package:war2aty/core/accessibility/usecases/get_text_size.dart';
import 'package:war2aty/core/accessibility/usecases/set_text_size.dart';

import '../../support/fakes.dart';

void main() {
  TextSizeCubit buildCubit([FakeTextSizeStore? store]) {
    final s = store ?? FakeTextSizeStore();
    final cubit = TextSizeCubit(
      getTextSize: GetTextSize(s),
      setTextSize: SetTextSize(s),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts with TextSize.normal', () {
    expect(buildCubit().state, TextSize.normal);
  });

  test('load() keeps normal when nothing is persisted', () async {
    final cubit = buildCubit();
    await cubit.load();
    expect(cubit.state, TextSize.normal);
  });

  test('load() restores a persisted size', () async {
    final cubit = buildCubit(FakeTextSizeStore(TextSize.veryLarge));
    await cubit.load();
    expect(cubit.state, TextSize.veryLarge);
  });

  test('setTextSize() emits and persists', () async {
    final store = FakeTextSizeStore();
    final cubit = buildCubit(store);
    await cubit.load();

    await cubit.setTextSize(TextSize.large);

    expect(cubit.state, TextSize.large);
    expect(await store.readSize(), TextSize.large);
  });

  test('setTextSize() with same value is a no-op', () async {
    final store = FakeTextSizeStore();
    final cubit = buildCubit(store);
    await cubit.load();

    // State starts at normal; setting normal again should not emit.
    var emitCount = 0;
    cubit.stream.listen((_) => emitCount++);
    await cubit.setTextSize(TextSize.normal);

    expect(emitCount, 0);
    // Store was never written (still null).
    expect(await store.readSize(), isNull);
  });
}
