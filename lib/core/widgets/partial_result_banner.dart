import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'compact_alert_banner.dart';

const double _gapBelow = AppSpacing.resultCardGap;

/// «قدرنا نفهم جزء من الورقة» — said above a result that is only half read.
///
/// A partial result is still shown rather than thrown away: what was
/// understood is usually the part the user came for. But the figures are
/// preceded by this, because a page that looks like every other result would
/// be read as a complete one — and the uncertain values each carry their own
/// caution too (UX rules §5.9, §5.11). Same compact banner as the warnings
/// (F21 #10); it sits right before the data card, after the warnings (F21
/// #17), so the top of the page stays the summary's.
class PartialResultBanner extends StatelessWidget {
  const PartialResultBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _gapBelow),
      child: CompactAlertBanner(text: context.strings.resultPartialBanner),
    );
  }
}
