import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/privacy_policy_content.dart';
import '../cubit/onboarding_cubit.dart';
import '../widgets/primary_cta.dart';

// From `Waraqti.dc.html` → `privacy`. As on the intro page, the design's 64px
// top padding is measured from the physical screen top and already contains
// the 52px status bar, which [SafeArea] applies for us.
const double _pageTop = 64 - 52;
const double _pageSide = 26;
const double _pageBottom = 26;

/// The last first-run step: what the app does with the user's paper, in four
/// plain promises. Agreeing here flips the onboarding flag, which opens the
/// router gate to Home.
///
/// The promises themselves are [PrivacyPolicyContent] — this screen is just
/// that content plus the «موافق، ابدأ» CTA that flips the onboarding flag.
/// The settings screen's «سياسة الخصوصية» row (F11-T12) reads the same
/// content back later, with no CTA.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _pageSide,
            _pageTop,
            _pageSide,
            _pageBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                child: SingleChildScrollView(child: PrivacyPolicyContent()),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryCta(
                label: s.privacyAgree,
                onPressed: () => context.read<OnboardingCubit>().complete(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
