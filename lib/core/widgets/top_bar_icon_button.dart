import 'package:flutter/material.dart';

/// A top-bar's back/close icon button — sized to the WCAG 2.5.5 / Material
/// 48dp minimum tap target (F12-T01).
///
/// Every screen's top bar (analysis result, reminder form/details, saved
/// document, the extracted-text fallback) built this by hand as
/// `SizedBox.square(dimension: 40, child: IconButton(...))` — duplicated
/// across five files and, at 40dp, under the tap-target floor. This is the
/// one shared version (CLAUDE.md: reusable UI used in 2+ places belongs in
/// `core/`).
///
/// The visible icon is unchanged — only the tappable/semantics area grows
/// from 40 to 48dp, centered on the same icon. [dimension] is exposed so a
/// row's balancing spacer (`SizedBox(width: TopBarIconButton.dimension)`,
/// used to keep a centered title centered when there is no trailing action)
/// stays in sync with the button's own size.
class TopBarIconButton extends StatelessWidget {
  const TopBarIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    super.key,
  });

  /// Tap target and balancing-spacer size (Material / WCAG 2.5.5 minimum).
  static const double dimension = 48;

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        icon: icon,
      ),
    );
  }
}
