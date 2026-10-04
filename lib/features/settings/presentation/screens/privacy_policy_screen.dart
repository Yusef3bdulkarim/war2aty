import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/privacy_policy_content.dart';
import '../../../../core/widgets/teal_top_bar.dart';

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
              child: PrivacyPolicyContent(),
            ),
          ),
        ],
      ),
    );
  }
}
