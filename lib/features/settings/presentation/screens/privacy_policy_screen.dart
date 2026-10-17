import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/legal/legal_links.dart';
import '../../../../core/legal/presentation/legal_links_cubit.dart';
import '../../../../core/legal/presentation/legal_links_state.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/privacy_policy_content.dart';
import '../../../../core/widgets/teal_top_bar.dart';

const double _pageSide = 26;
const double _pageTop = 22;
const double _pageBottom = 32;

/// Takes each footer link's hit box past the 48 dp minimum (F27-T20).
const double _linkPaddingV = 12;

/// «سياسة الخصوصية» (F11-T12) — the same four promises [PrivacyPolicyContent]
/// makes on first run, read back at any time from the settings screen's «عن
/// التطبيق» section. No CTA: agreeing already happened on first run.
///
/// F27-T20 added the footer out to the published policy. The four promises are
/// a summary — true, and deliberately short enough to be read — while the full
/// document says what reaches our server, how long it is kept and how to have
/// it deleted. The link lives here and **not** in [PrivacyPolicyContent],
/// because that widget is also the first-run step: sending a user to a browser
/// before they have even agreed would be the wrong moment.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({this.onClose, super.key});

  /// Leaves the screen. The router supplies it; optional so the screen can
  /// be pumped on its own in a widget test.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: [
          TealTopBar(
            title: context.strings.settingsPrivacyPolicyLabel,
            backTooltip: context.strings.analysisResultBackLabel,
            onBack: onClose,
          ),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                _pageSide,
                _pageTop,
                _pageSide,
                _pageBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrivacyPolicyContent(),
                  SizedBox(height: AppSpacing.xl),
                  _PublishedPolicyLinks(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two links out of the app: the full policy, and the terms beside it.
///
/// A plain text button rather than a new component: the design system has no
/// link style, and inventing a decorated one here would be a design decision
/// taken in the wrong place. Brand colour, underlined, at body size — which
/// also keeps it legible at the 2.0 text scale the audit underwrites.
class _PublishedPolicyLinks extends StatelessWidget {
  const _PublishedPolicyLinks();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = AppColors.of(context);

    // Same reasoning as the settings rows (F27-T20): on a device with no
    // browser the tap does nothing at all unless we say so.
    return BlocListener<LegalLinksCubit, LegalLinksState>(
      listener: (context, state) {
        if (state is! LegalLinkUnavailable) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(strings.legalPageOpenFailed)));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, link) in [
            (strings.privacyFullPolicyLabel, LegalLink.privacyPolicy),
            (strings.settingsTermsOfUseLabel, LegalLink.termsOfUse),
          ])
            // `Semantics(button:)` + `InkWell` + vertical padding, not a bare
            // `GestureDetector` on the text: that gave a tap target one line
            // tall (~24 dp) and announced nothing to a screen reader — in an
            // app written for readers with poor eyesight. The padding takes
            // the hit box past 48 dp and the row gains a ripple, matching
            // `SettingsNavRow`'s own shape.
            Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => context.read<LegalLinksCubit>().open(link),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: _linkPaddingV,
                    ),
                    child: Text(
                      label,
                      style: AppTypography.bodyLarge.copyWith(
                        color: colors.brandPrimary,
                        fontWeight: AppTypography.semiBold,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.brandPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
