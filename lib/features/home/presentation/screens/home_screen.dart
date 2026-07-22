import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/home_empty_state.dart';
import '../widgets/home_greeting.dart';
import '../widgets/recent_documents_strip.dart';
import '../widgets/scan_actions.dart';
import '../widgets/upcoming_reminder_card.dart';
import '../widgets/usage_indicator.dart';

// From `Waraqti.dc.html` → `home`. The 64px top padding is measured from the
// physical screen top and already contains the 52px status bar, which
// [SafeArea] applies for us; the 108px bottom clears the translucent nav bar.
const double _pageTop = 64 - 52;
const double _pageSide = 20;
const double _pageBottom = 108;

/// The Home hub.
///
/// Each section below owns its own visibility, spacing and loading placeholder,
/// so this column stays a plain list: the screen never has to reason about
/// which of them is currently showing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({this.onScan, this.onPickImage, super.key});

  /// Where the two scan actions lead — the router supplies both.
  ///
  /// Optional so the screen can be pumped on its own in a widget test without
  /// a router; in the app they are always wired to the capture route.
  final VoidCallback? onScan;
  final VoidCallback? onPickImage;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Scaffold(
      backgroundColor: colors.surface,
      // No AppBar: the design's Home leads with its own greeting instead.
      body: SafeArea(
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
              const HomeGreeting(),
              const SizedBox(height: AppSpacing.xl),
              ScanActions(
                onScan: onScan ?? () {},
                onPickImage: onPickImage ?? () {},
              ),
              // Rebuilt only when the usage section changes, not on every
              // Home update — the scan actions above never need to rebuild.
              BlocSelector<HomeCubit, HomeState, UsageSection>(
                selector: (state) => state.usage,
                builder: (context, usage) => UsageIndicator(section: usage),
              ),
              // Order follows the design: the thing with a deadline comes
              // before the archive of things already dealt with.
              BlocSelector<HomeCubit, HomeState, ReminderSection>(
                selector: (state) => state.reminder,
                builder: (context, reminder) =>
                    UpcomingReminderCard(section: reminder),
              ),
              BlocSelector<HomeCubit, HomeState, DocumentsSection>(
                selector: (state) => state.documents,
                builder: (context, documents) =>
                    RecentDocumentsStrip(section: documents),
              ),
              // Depends on two sections at once, so it selects the pair —
              // records compare by value, so this still rebuilds only when
              // one of them actually changes.
              BlocSelector<
                HomeCubit,
                HomeState,
                (ReminderSection, DocumentsSection)
              >(
                selector: (state) => (state.reminder, state.documents),
                builder: (context, sections) => HomeEmptyState(
                  reminder: sections.$1,
                  documents: sections.$2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
