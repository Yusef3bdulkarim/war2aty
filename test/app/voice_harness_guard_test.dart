import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';

import '../support/fakes.dart';

/// F37-T21 · the dev voice harness cannot reach a release build.
///
/// The harness exists because F37 builds no screen, so the Kotlin audio path
/// had no way to run on a phone (see `F37-device-checklist.md`). The owner
/// chose to open the scope fence for it — which makes "it is dev-only" a claim
/// that has to be enforced, not a comment.
///
/// Two layers are asserted, because either alone is one mistake away from
/// shipping a debug tool in the store build:
///
/// 1. **The default is off.** `createAppRouter` must not register the route
///    unless asked. A future caller that forgets the argument gets a router
///    with no such path, rather than one that quietly carries it.
/// 2. **The one real caller requires `isDev`.** The registration in
///    `service_locator.dart` is read as text: a dart-define alone must not be
///    able to turn the harness on in a release build.
///
/// Reading the source for (2) is deliberate. The alternative is building a
/// prod environment and resolving the router, which pulls in Supabase — and
/// the thing being protected is a *condition in one expression*, which is
/// exactly what text can check and a runtime test cannot isolate.
void main() {
  group('the route is absent by default', () {
    test('no route matches the harness path', () async {
      final onboarding = OnboardingCubit(
        hasSeenOnboarding: HasSeenOnboarding(
          FakeOnboardingRepository(seen: true),
        ),
        completeOnboarding: CompleteOnboarding(
          FakeOnboardingRepository(seen: true),
        ),
      );
      await onboarding.load();
      final router = createAppRouter(onboardingGate: onboarding);

      final match = router.configuration.findMatch(
        Uri.parse(AppRoutes.devVoiceHarness),
      );

      // go_router answers an unmatched location with an error match rather
      // than throwing, so the assertion is on the error being there.
      expect(
        match.error,
        isNotNull,
        reason:
            'the harness route is registered in a router that did not ask '
            'for it — a release build would carry a debug tool',
      );
    });
  });

  group('the caller gates it on the environment', () {
    final registration = File(
      'lib/app/di/service_locator.dart',
    ).readAsStringSync();

    test('the router is built with isDev in the condition', () {
      expect(
        registration,
        contains('getIt<AppEnvironment>().isDev'),
        reason:
            'the only `devVoiceHarness` argument must depend on isDev; '
            'without it a --dart-define would enable the harness in release',
      );
    });

    test('the dart-define alone does not enable it', () {
      // The two conditions must be ANDed. A refactor that drops the `&&` and
      // passes the define on its own is the specific regression here.
      final condition = RegExp(
        r'devVoiceHarness:\s*(//[^\n]*\n\s*)*'
        r'getIt<AppEnvironment>\(\)\.isDev\s*&&\s*'
        r"const bool\.fromEnvironment\('VOICE_HARNESS'\)",
      );

      expect(
        condition.hasMatch(registration),
        isTrue,
        reason:
            'devVoiceHarness must be `isDev && bool.fromEnvironment(...)`; '
            'the current expression does not match that shape',
      );
    });
  });

  group('the harness itself stays out of the product', () {
    test('nothing in lib/ imports it except the router', () {
      final importers = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.endsWith('lib/app/dev/voice_harness_screen.dart')) continue;

        if (entity.readAsStringSync().contains('voice_harness_screen.dart')) {
          importers.add(path);
        }
      }

      expect(
        importers,
        ['lib/app/router/app_router.dart'],
        reason:
            'the harness is a tool behind one guarded route; a second importer '
            'is a path into it that this guard does not cover',
      );
    });
  });
}
