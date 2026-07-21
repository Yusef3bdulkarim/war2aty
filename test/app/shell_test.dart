import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_cubit.dart';

import '../support/fakes.dart';

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  Future<void> pumpShell(WidgetTester tester, {String? persisted}) async {
    getIt
      ..registerFactory<LocaleCubit>(() {
        final store = FakeLocaleStore(persisted);
        return LocaleCubit(
          getSavedLocale: GetSavedLocale(store),
          setLocale: SetLocale(store),
        );
      })
      // An empty launch sequence succeeds immediately, so the shell is shown.
      ..registerFactory<BootstrapCubit>(
        () => BootstrapCubit(InitializeApp(const [])),
      )
      ..registerLazySingleton<GoRouter>(createAppRouter);
    await tester.pumpWidget(const WaraqtiApp());
    await tester.pumpAndSettle();
  }

  TextDirection navDirection(WidgetTester tester) =>
      Directionality.of(tester.element(find.byType(NavigationBar)));

  testWidgets('boots to a 4-tab shell in Arabic (RTL)', (tester) async {
    await pumpShell(tester);
    const ar = ArStrings();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(ar.navHome), findsWidgets);
    expect(find.text(ar.navSaved), findsWidgets);
    expect(find.text(ar.navReminders), findsWidgets);
    expect(find.text(ar.navSettings), findsWidgets);
    expect(navDirection(tester), TextDirection.rtl);
  });

  testWidgets('boots in English (LTR) when that language is persisted', (
    tester,
  ) async {
    await pumpShell(tester, persisted: 'en');
    const en = EnStrings();

    expect(find.text(en.navHome), findsWidgets);
    expect(find.text(en.navSettings), findsWidgets);
    expect(navDirection(tester), TextDirection.ltr);
  });
}
