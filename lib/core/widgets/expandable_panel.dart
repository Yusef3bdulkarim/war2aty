import 'package:flutter/material.dart';

import '../icons/stroke_icon.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

// From `Waraqti.dc.html` → the result page's two collapsible panels.
const double _headerPaddingH = 18;
const double _headerPaddingV = 16;
const double _labelFontSize = 15.5;
const double _labelGap = 12;
const double _chevronSize = 20;
const double _bodyPaddingH = 18;
const double _bodyPaddingBottom = 18;
const double _bodyPaddingTop = 6;
const Duration _turn = Duration(milliseconds: 180);

/// The body slides open and shut in place (F21 locked decision #13).
const Duration _slide = Duration(milliseconds: 220);

/// A titled panel the user opens to read the long text inside it.
///
/// The page ends with two of these — the full explanation and what was read
/// off the paper. Both are collapsed to start: they are the longest blocks on
/// the page and would push the answer, the dates and the actions out of reach
/// of a first glance. Neither is hidden, though; the title says exactly what
/// is inside.
///
/// The design draws the open panel as a second card butted under the header;
/// it is one continuous surface here, which is what that trick is drawing.
class ExpandablePanel extends StatefulWidget {
  const ExpandablePanel({
    required this.label,
    required this.child,
    this.gapAbove = 0,
    this.gapBelow = 0,
    super.key,
  });

  /// What the panel holds — shown whether it is open or not.
  final String label;

  /// Built only while the panel is open (or sliding shut): these bodies are
  /// long runs of text, and there may be two of them on the page.
  final Widget child;

  final double gapAbove;
  final double gapBelow;

  @override
  State<ExpandablePanel> createState() => _ExpandablePanelState();
}

class _ExpandablePanelState extends State<ExpandablePanel>
    with SingleTickerProviderStateMixin {
  // Local UI state, held at the smallest widget that needs it (CLAUDE.md §2).
  bool _open = false;

  /// How far open the body is. Its value drives the slide; once it is back at
  /// 0 the body is no longer built at all.
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _slide)
        ..addStatusListener((status) {
          // Fully shut: rebuild so the body is dropped rather than kept at
          // zero height.
          if (status == AnimationStatus.dismissed && mounted) setState(() {});
        });

  late final CurvedAnimation _slideIn = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  void _toggle() {
    setState(() => _open = !_open);
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: open and shut at once, with no ticker running.
      _controller.value = _open ? 1 : 0;
    } else if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _slideIn.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: EdgeInsets.only(top: widget.gapAbove, bottom: widget.gapBelow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.low,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: _open,
                // A transparent [Material] above the card's own fill, so the
                // tap ripple paints on top of it. Without one the splash goes
                // to the page's Material, behind this card, and is invisible.
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: _toggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _headerPaddingH,
                        vertical: _headerPaddingV,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.label,
                              style: AppTypography.labelCard.copyWith(
                                fontSize: _labelFontSize,
                                fontWeight: AppTypography.bold,
                                color: colors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: _labelGap),
                          AnimatedRotation(
                            duration: reduceMotion ? Duration.zero : _turn,
                            turns: _open ? 0.5 : 0,
                            child: StrokeIcon(
                              StrokeGlyph.chevronDown,
                              color: colors.textMuted,
                              size: _chevronSize,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Built while open and while sliding shut, never once closed:
              // the bodies are long runs of text.
              if (_open || !_controller.isDismissed)
                SizeTransition(
                  sizeFactor: _slideIn,
                  axisAlignment: -1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _bodyPaddingH,
                      _bodyPaddingTop,
                      _bodyPaddingH,
                      _bodyPaddingBottom,
                    ),
                    child: widget.child,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
