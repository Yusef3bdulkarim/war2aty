import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../features/bootstrap/presentation/widgets/splash_hand_off.dart';
import '../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../features/onboarding/presentation/cubit/onboarding_state.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import 'di/service_locator.dart';
import 'launch_reveal.dart';
import 'notifications/reminder_notification_opener.dart';
import 'notifications/reminder_notification_taps.dart';

/// Root widget.
///
/// The app launches into [SplashScreen], which runs the ordered init sequence
/// and offers a retry if a critical step fails. Only once launch succeeds does
/// the router shell take over, built under the splash, which [SplashHandOff]
/// then fades off it. Text direction follows the active locale
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
                      final ready =
                          bootstrapState is BootstrapSuccess &&
                          gate is! OnboardingUnknown;

                      // The app is built under the splash, which then fades
                      // off it (F27-P01) — never a cut from one to the other.
                      return SplashHandOff(
                        isContentReady: () =>
                            getIt<LaunchReveal>().contentReady,
                        onRevealed: () {
                          // Order matters: a notification tap that launched
                          // the app opens as soon as the splash is gone,
                          // before the housekeeping it no longer waits for.
                          getIt<LaunchReveal>().markRevealed();
                          context.read<BootstrapCubit>().finishLaunch();
                        },
                        app: ready
                            ? MaterialApp.router(
                                onGenerateTitle: (context) =>
                                    context.strings.appName,
                                debugShowCheckedModeBanner: false,
                                theme: highContrast
                                    ? AppTheme.highContrast()
                                    : AppTheme.light(),
                                locale: locale,
                                supportedLocales:
                                    AppLocalizations.supportedLocales,
                                localizationsDelegates:
                                    AppLocalizations.delegates,
                                localeResolutionCallback:
                                    AppLocalizations.resolve,
                                routerConfig: getIt<GoRouter>(),
                                builder: _withNotificationOpener(
                                  _appBuilder(textSize, highContrast),
                                ),
                              )
                            : null,
                        splash: MaterialApp(
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
                        ),
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

/// Wraps [builder] so a reminder notification tap opens that reminder
/// (F25-T04) — only on the router's app, the one that can navigate.
TransitionBuilder _withNotificationOpener(TransitionBuilder builder) =>
    (context, child) => ReminderNotificationOpener(
      taps: getIt<ReminderNotificationTaps>(),
      router: getIt<GoRouter>(),
      revealed: getIt<LaunchReveal>().revealed,
      child: builder(context, child),
    );

/// Returns the [MaterialApp.builder] that applies the user's [TextSize]
/// (F11-T05) and active [AppColors] palette (F11-T06).
///
/// The scaler is [resolveTextScaler]'s: the larger of the OS's text size and
/// the user's choice, capped at [kMaxTextScale]. [TextSize.normal] still goes
/// through it, because "normal" means "don't add anything of our own", not
/// "ignore the phone's accessibility settings" — which is what this builder
/// used to do (F27-T15). [AppColorsScope]
/// is installed here too, above every route, so [AppColors.of] resolves
/// [highContrast] anywhere in the tree — the same reach [MediaQuery] already
/// has.
TransitionBuilder _appBuilder(TextSize textSize, bool highContrast) {
  final colors = highContrast ? AppColors.highContrast : AppColors.light;
  return (context, child) {
    // Dark status-bar icons by default: almost every screen is the light
    // surface. A screen on a dark or teal surface asks for light ones with
    // its own region — the result hero, the camera, the photo preview (F21).
    // Without this default, Flutter would keep whichever style the last such
    // screen asked for, leaving white icons on the light screens after it.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: AppColorsScope(
        colors: colors,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: resolveTextScaler(
              MediaQuery.textScalerOf(context),
              textSize,
            ),
          ),
          child: child!,
        ),
      ),
    );
  };
}
