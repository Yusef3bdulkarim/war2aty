import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../core/localization/locale_cubit.dart';
import '../core/theme/app_theme.dart';
import '../features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import '../features/bootstrap/presentation/cubit/bootstrap_state.dart';
import '../features/bootstrap/presentation/screens/splash_screen.dart';
import 'di/service_locator.dart';

/// Root widget.
///
/// The app launches into [SplashScreen], which runs the ordered init sequence
/// and offers a retry if a critical step fails. Only once launch succeeds does
/// the router shell take over. Text direction follows the active locale
/// automatically (Arabic → RTL, English → LTR).
class WaraqtiApp extends StatelessWidget {
  const WaraqtiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleCubit>(create: (_) => getIt<LocaleCubit>()..load()),
        BlocProvider<BootstrapCubit>(
          create: (_) => getIt<BootstrapCubit>()..start(),
        ),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<BootstrapCubit, BootstrapState>(
            // Only the launch/ready switch matters here, not every stage tick.
            buildWhen: (previous, current) =>
                (previous is BootstrapSuccess) != (current is BootstrapSuccess),
            builder: (context, bootstrapState) {
              if (bootstrapState is BootstrapSuccess) {
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
              }

              return MaterialApp(
                onGenerateTitle: (context) => context.strings.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.delegates,
                localeResolutionCallback: AppLocalizations.resolve,
                home: const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
