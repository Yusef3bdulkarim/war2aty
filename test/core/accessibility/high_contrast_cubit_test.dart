import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/accessibility/high_contrast_cubit.dart';
import 'package:war2aty/core/accessibility/usecases/get_high_contrast.dart';
import 'package:war2aty/core/accessibility/usecases/set_high_contrast.dart';

import '../../support/fakes.dart';

void main() {
  HighContrastCubit buildCubit([FakeHighContrastStore? store]) {
    final s = store ?? FakeHighContrastStore();
    final cubit = HighContrastCubit(
      getHighContrast: GetHighContrast(s),
      setHighContrast: SetHighContrast(s),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts false', () {
    expect(buildCubit().state, isFalse);
  });

  test('load() keeps false when nothing is persisted', () async {
    final cubit = buildCubit();
    await cubit.load();
    expect(cubit.state, isFalse);
  });

  test('load() restores a persisted true', () async {
    final cubit = buildCubit(FakeHighContrastStore(true));
    await cubit.load();
    expect(cubit.state, isTrue);
  });

  test('setHighContrast() emits and persists', () async {
    final store = FakeHighContrastStore();
    final cubit = buildCubit(store);
    await cubit.load();

    await cubit.setHighContrast(true);

    expect(cubit.state, isTrue);
    expect(await store.readEnabled(), isTrue);
  });

  test('setHighContrast() with the same value is a no-op', () async {
    final store = FakeHighContrastStore();
    final cubit = buildCubit(store);
    await cubit.load();

    // State starts at false; setting false again should not emit.
    var emitCount = 0;
    cubit.stream.listen((_) => emitCount++);
    await cubit.setHighContrast(false);

    expect(emitCount, 0);
    // Store was never written (still null).
    expect(await store.readEnabled(), isNull);
  });
}
