import 'package:flutter/material.dart';

import '../documents/analysis_warning.dart';
import '../localization/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'compact_alert_banner.dart';

// The owner's result-screen review (F21 locked decision #10).
const double _gapBelow = AppSpacing.resultCardGap;
const double _warningGap = 8;

/// The medical, legal, financial and government disclaimers — one compact
/// banner each.
///
/// §4 puts these above the figures, and that placement is the point: they are
/// cautions to read *before* acting on anything further down the page, not
/// footnotes under it.
///
/// The «تنبيه مهم» heading is no longer drawn (F21 locked decision #10), but a
/// screen reader still hears it in front of each warning, and the audio reader
/// still speaks it.
///
/// `WarningKind` chooses no icon of its own here: the design draws one
/// treatment for all four, and a per-kind mark would be invention.
class ResultWarningsCard extends StatelessWidget {
  const ResultWarningsCard({required this.warnings, super.key});

  /// Never empty — `BuildAnalysisResult` drops the section otherwise.
  final List<AnalysisWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(bottom: _gapBelow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, warning) in warnings.indexed) ...[
            if (index > 0) const SizedBox(height: _warningGap),
            CompactAlertBanner(
              text: warning.text,
              semanticsLabel: '${strings.resultWarningsTitle}: ${warning.text}',
            ),
          ],
        ],
      ),
    );
  }
}
