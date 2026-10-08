import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/legal/legal_links.dart';
import 'package:war2aty/core/legal/presentation/legal_links_cubit.dart';
import 'package:war2aty/core/legal/system_legal_link_repository.dart';
import 'package:war2aty/core/legal/usecases/open_legal_link.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/widgets/teal_top_bar.dart';
import 'package:war2aty/features/settings/presentation/screens/privacy_policy_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/ui_audit.dart';

// F11-T12: the settings screen's «سياسة الخصوصية» row opens this — the same
// four promises `PrivacyScreen` makes on first run, read back with a back
// control instead of a CTA.
void main() {
  const ar = ArStrings();
  const en = EnStrings();

  // F27-T20 gave the screen a footer that links out to the published pages,
  // so it now needs the cubit the app provides at the root. The fake records
  // instead of leaving the app.
  late FakeExternalLinkService links;

  setUp(() => links = FakeExternalLinkService());

  Widget screen({VoidCallback? onClose}) => BlocProvider<LegalLinksCubit>(
    create: (_) => LegalLinksCubit(
      openLegalLink: OpenLegalLink(SystemLegalLinkRepository(links)),
    ),
    child: PrivacyPolicyScreen(onClose: onClose),
  );

  auditScreenLayout(
    'PrivacyPolicyScreen',
    (tester, locale, scaler) =>
        pumpApp(tester, screen(), locale: locale, textScaler: scaler),
  );

  testWidgets('shows the title and all four privacy promises', (tester) async {
    await pumpApp(tester, screen());

    expect(find.text(ar.settingsPrivacyPolicyLabel), findsOneWidget);
    expect(find.text(ar.privacyTitle), findsOneWidget);
    expect(find.text(ar.privacyPointExtractText), findsOneWidget);
    expect(find.text(ar.privacyPointTextOnly), findsOneWidget);
    expect(find.text(ar.privacyPointImageOptIn), findsOneWidget);
    expect(find.text(ar.privacyPointDeleteAnytime), findsOneWidget);
  });

  testWidgets('titles the page on the teal top bar (F26-T02)', (tester) async {
    await pumpApp(tester, screen());

    expect(
      find.descendant(
        of: find.byType(TealTopBar),
        matching: find.text(ar.settingsPrivacyPolicyLabel),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows no CTA — agreeing already happened on first run', (
    tester,
  ) async {
    await pumpApp(tester, screen());

    expect(find.text(ar.privacyAgree), findsNothing);
  });

  testWidgets('tapping back calls onClose', (tester) async {
    var closed = false;
    await pumpApp(tester, screen(onClose: () => closed = true));

    await tester.tap(find.byTooltip(ar.analysisResultBackLabel));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('renders in English, left-to-right', (tester) async {
    await pumpApp(tester, screen(), locale: AppLocalizations.english);

    expect(find.text(en.settingsPrivacyPolicyLabel), findsOneWidget);
    expect(find.text(en.privacyTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(PrivacyPolicyScreen))),
      TextDirection.ltr,
    );
  });

  testWidgets('the footer opens the published policy and terms (F27-T20)', (
    tester,
  ) async {
    await pumpApp(tester, screen());

    await tester.tap(find.text(ar.privacyFullPolicyLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ar.settingsTermsOfUseLabel));
    await tester.pumpAndSettle();

    // The URLs, not just "something was opened": a footer that silently
    // pointed at the wrong page would pass any looser assertion.
    expect(links.opened, [
      Uri.parse(privacyPolicyUrl),
      Uri.parse(termsOfUseUrl),
    ]);
  });

  testWidgets('each footer link is a button, big enough to hit', (
    tester,
  ) async {
    // The first version was a GestureDetector around a Text: a tap target one
    // line tall and silent to a screen reader, in an app written for readers
    // with poor eyesight.
    await pumpApp(tester, screen());

    for (final label in [
      ar.privacyFullPolicyLabel,
      ar.settingsTermsOfUseLabel,
    ]) {
      final link = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(link, findsOneWidget, reason: '$label must be tappable as a row');
      expect(
        tester.getSize(link).height,
        greaterThanOrEqualTo(48),
        reason: '$label is below the 48 dp minimum tap target',
      );
      expect(
        tester.getSemantics(link).hasFlag(SemanticsFlag.isButton),
        isTrue,
        reason: '$label must announce itself as a button',
      );
    }
  }, semanticsEnabled: true);

  testWidgets('says so when nothing on the device can open the page', (
    tester,
  ) async {
    // CLAUDE.md §A3: the tap must not look ignored.
    links.result = false;
    await pumpApp(tester, screen());

    await tester.tap(find.text(ar.privacyFullPolicyLabel));
    await tester.pumpAndSettle();

    expect(find.text(ar.legalPageOpenFailed), findsOneWidget);
  });

  testWidgets('survives large text without overflowing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, screen(), textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(find.text(ar.settingsPrivacyPolicyLabel), findsOneWidget);
  });
}
