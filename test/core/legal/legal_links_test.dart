import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/legal/legal_links.dart';
import 'package:war2aty/core/legal/presentation/legal_links_cubit.dart';
import 'package:war2aty/core/legal/presentation/legal_links_state.dart';
import 'package:war2aty/core/legal/system_legal_link_repository.dart';
import 'package:war2aty/core/legal/usecases/open_legal_link.dart';
import 'package:war2aty/core/platform/external_link_service.dart';
import 'package:war2aty/core/result/result.dart';

/// Records what it was asked to open, and answers however the test says.
final class _FakeExternalLinkService implements ExternalLinkService {
  _FakeExternalLinkService({this.result = true, this.throws = false});

  bool result;
  bool throws;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri destination) async {
    opened.add(destination);
    if (throws) throw Exception('no activity found');
    return result;
  }
}

/// F27-T20 · The links out of the app, and the one way they are allowed to
/// fail.
void main() {
  group('the destinations', () {
    test('point at the pages that actually exist in legal/', () {
      // The published site is a copy of `legal/` at the root of the `gh-pages`
      // branch, so a page renamed there and not here ships a dead link inside
      // the app — and nothing else in the suite would notice, because the
      // constant is still a perfectly valid string.
      for (final (link, file) in [
        (LegalLink.privacyPolicy, 'privacy.html'),
        (LegalLink.termsOfUse, 'terms.html'),
      ]) {
        expect(
          File('legal/$file').existsSync(),
          isTrue,
          reason: 'legal/$file is missing, so $link would 404',
        );
        expect(
          link.uri.toString(),
          '$legalSiteBase/$file',
          reason: '$link must point at legal/$file on the published site',
        );
      }
    });

    test('the site is served over HTTPS', () {
      // The pages carry the privacy promises; served over plain HTTP they
      // could be rewritten in transit.
      expect(Uri.parse(legalSiteBase).scheme, 'https');
      expect(LegalLink.privacyPolicy.uri.scheme, 'https');
      expect(LegalLink.termsOfUse.uri.scheme, 'https');
    });

    test('support is a mailto with the published address and nothing else', () {
      final uri = LegalLink.support.uri;

      expect(uri.scheme, 'mailto');
      expect(uri.path, supportEmailAddress);
      // No subject or body: prefilled Arabic arrives percent-encoded in some
      // mail clients and reads as noise.
      expect(uri.query, isEmpty);
    });

    test('the published address is not the owner\'s personal mailbox', () {
      // Q17 named a personal address; T20 published a dedicated one instead,
      // because this string appears on a public page and in a store listing.
      expect(supportEmailAddress, 'war2aty.support@gmail.com');
    });
  });

  group('the data boundary', () {
    test('a thrown platform error becomes a failure, never an exception', () {
      // CLAUDE.md §B5: exceptions stop at the data layer. A phone with no
      // activity for the scheme makes `url_launcher` throw.
      final repository = SystemLegalLinkRepository(
        _FakeExternalLinkService(throws: true),
      );

      expectLater(
        repository.open(LegalLink.privacyPolicy),
        completion(const Err<bool, AppFailure>(ExternalLinkFailure())),
      );
    });

    test('"nothing could open it" is a value, not a failure', () {
      // The two are different: one is the platform breaking, the other is an
      // honest "no app handles this". The user sees the same message, but the
      // log code should not claim a platform error.
      final repository = SystemLegalLinkRepository(
        _FakeExternalLinkService(result: false),
      );

      expectLater(
        repository.open(LegalLink.support),
        completion(const Ok<bool, AppFailure>(false)),
      );
    });

    test('it hands the platform the link\'s own uri', () {
      final service = _FakeExternalLinkService();
      final repository = SystemLegalLinkRepository(service);

      expectLater(
        repository.open(LegalLink.termsOfUse).then((_) => service.opened),
        completion([Uri.parse(termsOfUseUrl)]),
      );
    });
  });

  group('LegalLinksCubit', () {
    LegalLinksCubit cubitOver(_FakeExternalLinkService service) =>
        LegalLinksCubit(
          openLegalLink: OpenLegalLink(SystemLegalLinkRepository(service)),
        );

    test('says nothing when the link opened', () async {
      final service = _FakeExternalLinkService();
      final cubit = cubitOver(service);
      final states = <LegalLinksState>[];
      cubit.stream.listen(states.add);

      await cubit.open(LegalLink.privacyPolicy);

      expect(service.opened, [Uri.parse(privacyPolicyUrl)]);
      expect(cubit.state, isA<LegalLinksIdle>());
      expect(
        states.whereType<LegalLinkUnavailable>(),
        isEmpty,
        reason: 'a successful open must not produce an error message',
      );
      await cubit.close();
    });

    test('reports the link that could not be opened', () async {
      final cubit = cubitOver(_FakeExternalLinkService(result: false));

      await cubit.open(LegalLink.support);

      // Which link matters: the support case names the address in its
      // message, and the page case does not.
      expect(cubit.state, const LegalLinkUnavailable(LegalLink.support));
      await cubit.close();
    });

    test('reports a thrown platform error the same way', () async {
      // The user's situation is identical, and the copy does not pretend to
      // know which of the two happened.
      final cubit = cubitOver(_FakeExternalLinkService(throws: true));

      await cubit.open(LegalLink.termsOfUse);

      expect(cubit.state, const LegalLinkUnavailable(LegalLink.termsOfUse));
      await cubit.close();
    });

    test(
      'a second failed tap reports again instead of looking ignored',
      () async {
        final cubit = cubitOver(_FakeExternalLinkService(result: false));

        // Subscribed before acting and awaited after: collecting into a list
        // races the second emit, which is how this test first passed for the
        // wrong reason — one report instead of two.
        //
        // The order asserted here IS the mechanism, and it is not the one
        // guessed first: `Cubit.emit` drops a state equal to the current one
        // only *after* it has emitted at least once, so the opening idle goes
        // through even though the cubit already starts idle. What matters is
        // the idle before the second failure — without it the second failure
        // would equal the current state, be dropped, `BlocListener` would
        // never fire, and the row would look dead on the second tap.
        final emitted = expectLater(
          cubit.stream,
          emitsInOrder(const [
            LegalLinksIdle(),
            LegalLinkUnavailable(LegalLink.termsOfUse),
            LegalLinksIdle(),
            LegalLinkUnavailable(LegalLink.termsOfUse),
          ]),
        );

        await cubit.open(LegalLink.termsOfUse);
        await cubit.open(LegalLink.termsOfUse);
        await cubit.close();
        await emitted;
      },
    );
  });

  group('the app can actually open them on Android', () {
    // At targetSdk 30+ an app cannot resolve an intent it has not declared,
    // so without these entries `url_launcher` finds nothing and every row
    // added by T20 fails — on the phones the app ships to, and nowhere else.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

    test('an https VIEW intent is declared', () {
      expect(
        manifest,
        contains(
          '<intent> <action android:name="android.intent.action.VIEW"/> '
          '<data android:scheme="https"/> </intent>',
        ),
      );
    });

    test('a mailto SENDTO intent is declared', () {
      expect(
        manifest,
        contains(
          '<intent> <action android:name="android.intent.action.SENDTO"/> '
          '<data android:scheme="mailto"/> </intent>',
        ),
      );
    });
  });
}
