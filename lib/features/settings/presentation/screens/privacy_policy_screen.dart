import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/privacy_policy_content.dart';
import '../../../../core/widgets/top_bar_icon_button.dart';

// Mirrors `ReminderDetailsScreen`'s own top bar shape — the app's established
// pushed-screen header (card background, centered title, a back button
// balanced by an equal-width spacer).
const double _topBarTop = 56 - 52;
const double _topBarBottom = 12;
const double _topBarSide = AppSpacing.screenHorizontal;
const double _topBarGap = 8;
const double _pageSide = 26;
const double _pageTop = 22;
const double _pageBottom = 32;

/// «سياسة الخصوصية» (F11-T12) — the same four promises [PrivacyPolicyContent]
/// makes on first run, read back at any time from the settings screen's «عن
/// التطبيق» section. No CTA: agreeing already happened on first run.
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
          _TopBar(onClose: onClose),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                _pageSide,
                _pageTop,
                _pageSide,
                _pageBottom,
              ),
              child: PrivacyPolicyContent(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _topBarSide,
            _topBarTop,
            _topBarSide,
            _topBarBottom,
          ),
          child: Row(
            children: [
              TopBarIconButton(
                onPressed: onClose,
                tooltip: strings.analysisResultBackLabel,
                icon: Transform.flip(
                  flipX: mirror,
                  child: StrokeIcon(
                    StrokeGlyph.arrowBack,
                    color: colors.ink,
                    strokeWidth: 2,
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.settingsPrivacyPolicyLabel,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelCard.copyWith(
                      fontWeight: AppTypography.extraBold,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              // Balances the back button so the title stays centred, the
              // same trick `ReminderDetailsScreen`'s top bar uses.
              const SizedBox(width: TopBarIconButton.dimension),
            ],
          ),
        ),
      ),
    );
  }
}
