import 'package:flutter/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → `isSettings`. The 64px top already accounts for
// the status bar SafeArea applies for us, the same convention every other
// tab page in the shell uses (see `RemindersListScreen`).
const double _pageTop = 64 - 52;
const double _pageSide = 20;
const double _pageBottom = 108;
const double _headerGapBelow = 20;

/// The «الإعدادات» tab (F11-T01).
///
/// A scaffold only: the page background, safe area and page heading, matching
/// the design exactly. Each settings section is added by its own task
/// (F11-T02 onward) as a child of the scroll body below the heading — nothing
/// here is guessed ahead of the task that owns it.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _pageSide,
            _pageTop,
            _pageSide,
            _pageBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  // Same word the bottom nav already uses for this tab — the
                  // design's own H1 repeats it rather than coining a second
                  // string for the identical Arabic text.
                  context.strings.navSettings,
                  style: AppTypography.headlineLarge.copyWith(
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(height: _headerGapBelow),
            ],
          ),
        ),
      ),
    );
  }
}
