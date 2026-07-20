import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';

import '../../support/fakes.dart';

void main() {
  // Builds a cubit over a fake store and registers its close() teardown.
  LocaleCubit buildCubit(FakeLocaleStore store) {
    final cubit = LocaleCubit(
      getSavedLocale: GetSavedLocale(store),
      setLocale: SetLocale(store),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('defaults to Arabic', () {
    final cubit = buildCubit(FakeLocaleStore());
    expect(cubit.state, const Locale('ar'));
  });

  test('load() restores a persisted language', () async {
    final cubit = buildCubit(FakeLocaleStore('en'));
    await cubit.load();
    expect(cubit.state, const Locale('en'));
  });

  test('load() keeps default when nothing persisted', () async {
    final cubit = buildCubit(FakeLocaleStore());
    await cubit.load();
    expect(cubit.state, const Locale('ar'));
  });

  test('setLanguage() emits and persists', () async {
    final store = FakeLocaleStore();
    final cubit = buildCubit(store);
    await cubit.setLanguage('en');
    expect(cubit.state, const Locale('en'));
    expect(await store.readLanguageCode(), 'en');
  });

  test('setLanguage() is a no-op when unchanged', () async {
    final cubit = buildCubit(FakeLocaleStore());
    final emitted = <Locale>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setLanguage('ar');
    await sub.cancel();
    expect(emitted, isEmpty);
  });
}
