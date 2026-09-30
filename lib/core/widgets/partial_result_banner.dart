import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'compact_alert_banner.dart';

const double _gapBelow = AppSpacing.resultCardGap;

/// «قدرنا نفهم جزء من الورقة» — said above a result that is only half read.
///
/// A partial result is still shown rather than thrown away: what was
/// understood is usually the part the user came for. But it is topped with
/// this, because a page that looks like every other result would be read as a
/// complete one — and the uncertain values further down each carry their own
/// caution (UX rules §5.9, §5.11). Same compact banner as the warnings (F21
/// locked decision #10), and still the first thing on the page.
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
