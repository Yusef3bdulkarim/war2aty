import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../core/localization/locale_cubit.dart';
import '../core/theme/app_theme.dart';
import 'di/service_locator.dart';

/// Root widget: wires the router, theme, and locale into [MaterialApp.router].
///
/// Text direction follows the active locale automatically (Arabic → RTL,
/// English → LTR), so no explicit `Directionality` is needed here.
class WaraqtiApp extends StatelessWidget {
  const WaraqtiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LocaleCubit>(
      create: (_) => getIt<LocaleCubit>()..load(),
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            onGenerateTitle: (context) => context.strings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.delegates,
            localeResolutionCallback: AppLocalizations.resolve,
            routerConfig: getIt<GoRouter>(),
          );
        },
      ),
    );
  }
}
