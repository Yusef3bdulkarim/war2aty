import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/stroke_icon.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Nav bar measurements, from `Waraqti.dc.html`.
const double _barTopPadding = 8;
const double _barSidePadding = 12;
const double _barBottomPadding = 26;
const double _destinationIcon = 25;
const double _blurSigma = 6;

/// Ceiling on how far the tiny nav labels scale up. See the note where it is
/// applied — this is deliberately the only capped text in the app.
const double _maxLabelScale = 1.3;

/// Bottom-nav shell hosting the four top-level destinations.
///
/// The bar is drawn to the design rather than with Material's [NavigationBar]:
/// the design calls for a translucent, blurred surface with a hairline top
/// edge, stroke icons and small bold labels, none of which [NavigationBar]
/// exposes. Order follows the ambient [Directionality], so tabs read correctly
/// in both RTL (Arabic) and LTR (English).
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the current tab again pops it back to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return Scaffold(
      // The bar is translucent, so content scrolls under it rather than
      // stopping short of it.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _NavBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: _goBranch,
        destinations: [
          (StrokeGlyph.navHome, s.navHome),
          (StrokeGlyph.navDocuments, s.navDocuments),
          (StrokeGlyph.navReminders, s.navReminders),
          (StrokeGlyph.navSettings, s.navSettings),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<(StrokeGlyph, String)> destinations;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.94),
            border: Border(top: BorderSide(color: colors.borderSoft)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: _barTopPadding,
              left: _barSidePadding,
              right: _barSidePadding,
              // The design's 26px bottom padding stands in for the home
              // indicator; on hardware reporting a real inset, use that.
              bottom: bottomInset > 0 ? bottomInset : _barBottomPadding,
            ),
            child: Row(
              children: [
                for (final (index, (glyph, label)) in destinations.indexed)
                  // Equal shares: four fixed-width destinations cannot fit a
                  // scaled-up label, and would overflow the row.
                  Expanded(
                    child: _Destination(
                      glyph: glyph,
                      label: label,
                      selected: index == currentIndex,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final StrokeGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final color = selected ? colors.brandPrimary : colors.iconMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      // The label is announced by this node; excluding the subtree stops a
      // screen reader reading it a second time from the Text below. That also
      // drops the InkResponse's semantics, so the tap action is re-declared
      // here — without it the bar is announced but cannot be activated.
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StrokeIcon(
                glyph,
                color: color,
                size: _destinationIcon,
                strokeWidth: 1.9,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Four tabs cannot hold a fully scaled label, so this one caps
                // out early. It is safe to cap here and nowhere else: the icon
                // carries the meaning, and the untruncated label still reaches
                // screen readers through the Semantics node above.
                textScaler: TextScaler.linear(
                  MediaQuery.textScalerOf(
                    context,
                  ).scale(1).clamp(1, _maxLabelScale),
                ),
                style: AppTypography.micro.copyWith(
                  color: color,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
