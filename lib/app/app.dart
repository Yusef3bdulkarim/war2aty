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
import '../features/bootstrap/presentation/screens/launch_screen.dart';
import '../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../features/onboarding/presentation/cubit/onboarding_state.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import 'di/service_locator.dart';
import 'notifications/reminder_notification_opener.dart';
import 'notifications/reminder_notification_taps.dart';

/// Root widget.
///
/// The app launches into [LaunchScreen], which shows the launch frame while the
/// ordered init sequence runs and offers a retry if a critical step fails. Once
/// launch succeeds the router shell replaces it. Text direction follows the
/// active locale automatically (Arabic → RTL, English → LTR).
///
/// **F28-T02:** the swap from the launch screen to the router app is a plain
/// cut. The hand-off that used to build the app under an opaque splash and fade
/// the splash off it is deleted, and F28-T07 rebuilds it — so between those two
/// tasks the launch ends in a visible cut, which is the defect the old hand-off
/// existed to prevent. It is recorded here rather than left to be rediscovered.
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
                      // launch screen stays up.
                      final gate = context.watch<OnboardingCubit>().state;
                      final ready =
                          bootstrapState is BootstrapSuccess &&
                          gate is! OnboardingUnknown;

                      if (!ready) {
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
                          home: const LaunchScreen(),
                          builder: _appBuilder(textSize, highContrast),
                        );
                      }

                      // The deferred launch steps used to run once the splash
                      // had faded off, so they could not stutter the fade
                      // (F27-P01). With no fade left to protect, the equivalent
                      // moment is the app's own first frame; F28-T07 puts them
                      // back behind the new reveal.
                      return _FinishLaunchOnMounted(
                        child: MaterialApp.router(
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
                          builder: _withNotificationOpener(
                            _appBuilder(textSize, highContrast),
                          ),
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
///
/// No `revealed` gate while F28 is in flight: that gate held a tap back until
/// the splash had faded, so the reminder's page never slid in under the fade.
/// There is no fade between T02 and T07, and this app is only built once launch
/// is done, so opening straight away is correct rather than merely tolerable.
/// T07 passes the new mechanism's signal back in.
TransitionBuilder _withNotificationOpener(TransitionBuilder builder) =>
    (context, child) => ReminderNotificationOpener(
      taps: getIt<ReminderNotificationTaps>(),
      router: getIt<GoRouter>(),
      child: builder(context, child),
    );

/// Runs the deferred launch steps once, after the app's first frame.
///
/// Interim (F28-T02): a stand-in for the reveal that used to trigger them. It
/// is a widget rather than a call in `build` because the steps must not run
/// during a build, and because mounting is the one event that happens exactly
/// once however often the tree above it rebuilds.
class _FinishLaunchOnMounted extends StatefulWidget {
  const _FinishLaunchOnMounted({required this.child});

  final Widget child;

  @override
  State<_FinishLaunchOnMounted> createState() => _FinishLaunchOnMountedState();
}

class _FinishLaunchOnMountedState extends State<_FinishLaunchOnMounted> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<BootstrapCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cubit.finishLaunch();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

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
