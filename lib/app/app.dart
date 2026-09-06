import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/high_contrast_cubit.dart';
import '../core/accessibility/text_size.dart';
import '../core/accessibility/text_size_cubit.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_cubit.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import '../features/bootstrap/presentation/cubit/bootstrap_state.dart';
import '../features/bootstrap/presentation/screens/splash_screen.dart';
import '../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../features/onboarding/presentation/cubit/onboarding_state.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
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
        BlocProvider<TextSizeCubit>(
          create: (_) => getIt<TextSizeCubit>()..load(),
        ),
        BlocProvider<HighContrastCubit>(
          create: (_) => getIt<HighContrastCubit>()..load(),
        ),
        BlocProvider<BootstrapCubit>(
          create: (_) => getIt<BootstrapCubit>()..start(),
        ),
        // App-scoped singleton (the router reads it), so `.value` — it must
        // outlive this subtree. `load()` is idempotent.
        BlocProvider<OnboardingCubit>.value(
          value: getIt<OnboardingCubit>()..load(),
        ),
        // Eagerly loaded so every setting is already resolved by the time the
        // user reaches the Settings tab — previously created only on first tab
        // visit, causing a visible skeleton/delay split against the three
        // cubits above (which were always root-scoped). Now all six sections
        // appear together, no skeleton needed on normal hardware.
        BlocProvider<SettingsCubit>(
          create: (_) => getIt<SettingsCubit>()..load(),
        ),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<TextSizeCubit, TextSize>(
            builder: (context, textSize) {
              return BlocBuilder<HighContrastCubit, bool>(
                builder: (context, highContrast) {
                  return BlocBuilder<BootstrapCubit, BootstrapState>(
                    // Only the launch/ready switch matters here, not every
                    // stage tick.
                    buildWhen: (previous, current) =>
                        (previous is BootstrapSuccess) !=
                        (current is BootstrapSuccess),
                    builder: (context, bootstrapState) {
                      // The router is built only once the first-run flag is
                      // known, so its redirect resolves on the very first
                      // frame — no flash of the wrong screen. Until then the
                      // splash stays up.
                      final gate = context.watch<OnboardingCubit>().state;
                      if (bootstrapState is BootstrapSuccess &&
                          gate is! OnboardingUnknown) {
                        return MaterialApp.router(
                          onGenerateTitle: (context) => context.strings.appName,
                          debugShowCheckedModeBanner: false,
                          theme: highContrast
                              ? AppTheme.highContrast()
                              : AppTheme.light(),
                          locale: locale,
                          supportedLocales: AppLocalizations.supportedLocales,
                          localizationsDelegates: AppLocalizations.delegates,
                          localeResolutionCallback: AppLocalizations.resolve,
                          routerConfig: getIt<GoRouter>(),
                          builder: _appBuilder(textSize, highContrast),
                        );
                      }

                      return MaterialApp(
                        onGenerateTitle: (context) => context.strings.appName,
                        debugShowCheckedModeBanner: false,
                        theme: highContrast
                            ? AppTheme.highContrast()
                            : AppTheme.light(),
                        locale: locale,
                        supportedLocales: AppLocalizations.supportedLocales,
                        localizationsDelegates: AppLocalizations.delegates,
                        localeResolutionCallback: AppLocalizations.resolve,
                        home: const SplashScreen(),
                        builder: _appBuilder(textSize, highContrast),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Returns the [MaterialApp.builder] that applies the user's [TextSize]
/// (F11-T05) and active [AppColors] palette (F11-T06).
///
/// [TextSize.normal] still passes through — the builder replaces the
/// [MediaQuery.textScaler] with the user's choice regardless, so the app
/// controls its own scaling rather than inheriting the OS's. [AppColorsScope]
/// is installed here too, above every route, so [AppColors.of] resolves
/// [highContrast] anywhere in the tree — the same reach [MediaQuery] already
/// has.
TransitionBuilder _appBuilder(TextSize textSize, bool highContrast) {
  final colors = highContrast ? AppColors.highContrast : AppColors.light;
  return (context, child) {
    return AppColorsScope(
      colors: colors,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textSize.scaler),
        child: child!,
      ),
    );
  };
}
