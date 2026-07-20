import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';

import '../../support/fakes.dart';

void main() {
  test('defaults to Arabic', () {
    final cubit = LocaleCubit(FakeLocaleStore());
    expect(cubit.state, const Locale('ar'));
  });

  test('load() restores a persisted language', () async {
    final cubit = LocaleCubit(FakeLocaleStore('en'));
    await cubit.load();
    expect(cubit.state, const Locale('en'));
  });

  test('load() keeps default when nothing persisted', () async {
    final cubit = LocaleCubit(FakeLocaleStore());
    await cubit.load();
    expect(cubit.state, const Locale('ar'));
  });

  test('setLanguage() emits and persists', () async {
    final store = FakeLocaleStore();
    final cubit = LocaleCubit(store);
    await cubit.setLanguage('en');
    expect(cubit.state, const Locale('en'));
    expect(await store.readLanguageCode(), 'en');
  });

  test('setLanguage() is a no-op when unchanged', () async {
    final cubit = LocaleCubit(FakeLocaleStore());
    final emitted = <Locale>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setLanguage('ar');
    await sub.cancel();
    expect(emitted, isEmpty);
  });
}
