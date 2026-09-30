import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the analysis page.
const double _pagePadding = 40;
const double _iconBox = 90;
const double _iconBoxRadius = 26;
const double _iconSize = 46;
const double _iconGap = 30;
const double _titleGap = 10;
const double _messageGap = 30;
const double _barWidth = 220;
const double _barHeight = 8;
const double _barRadius = 6;

/// Endpoints of the design's 160° gradient, as unit offsets from the centre.
const Alignment _gradientBegin = Alignment(-0.342, -0.940);
const Alignment _gradientEnd = Alignment(0.342, 0.940);

/// While the analysis runs, the fill approaches [_barWaitingTarget] over
/// [_barWaitingDuration] — longer than the server's 25 s deadline, so the bar
/// is still visibly moving when a slow analysis answers (L1 took 16.6 s).
const double _barWaitingTarget = 0.9;
const Duration _barWaitingDuration = Duration(seconds: 40);

/// How fast the approach flattens: about half the way by 5 s, three quarters
/// by 10 s, 85% of the way by 16 s.
const double _barApproachRate = 40 / 6;

/// Once the analysis has answered, the fill runs to full over this before the
/// result replaces the page.
const Duration _barFinishDuration = Duration(milliseconds: 350);

/// The full-bleed page shown while the analysis service is working.
///
/// It says what is being prepared rather than naming a step: the user is
/// waiting on their paper being understood, not on a pipeline (UX rule §5.13 —
/// no technical terms). The bar is deliberately not a completion percentage —
/// it eases towards, and stops short of, full while the wait lasts.
///
/// Set [finishing] once the analysis has answered: the bar runs to full, then
/// [onFinished] fires so the caller can swap in the result. Removing the page
/// (an error, leaving the route) disposes the bar and halts it.
class AnalysisProgressView extends StatelessWidget {
  const AnalysisProgressView({
    this.finishing = false,
    this.onFinished,
    super.key,
  });

  final bool finishing;
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Plain [Alignment], not the directional variant: a CSS gradient angle
        // does not flip in an RTL container.
        gradient: LinearGradient(
          begin: _gradientBegin,
          end: _gradientEnd,
          colors: [colors.brandPrimary, colors.brandDeep],
        ),
      ),
      child: Semantics(
        liveRegion: true,
        label: strings.analysisRunningStatus,
        child: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _iconBox,
                height: _iconBox,
                decoration: BoxDecoration(
                  color: colors.onBrand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(_iconBoxRadius),
                ),
                child: Center(
                  child: StrokeIcon(
                    StrokeGlyph.sparkle,
                    color: colors.onBrand,
                    size: _iconSize,
                    strokeWidth: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: _iconGap),
              Text(
                strings.analysisRunningTitle,
                textAlign: TextAlign.center,
                style: AppTypography.titleAction.copyWith(
                  color: colors.onBrand,
                ),
              ),
              const SizedBox(height: _titleGap),
              Text(
                strings.analysisRunningMessage,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.medium,
                  color: colors.onBrand.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: _messageGap),
              _ProgressBar(finishing: finishing, onFinished: onFinished),
            ],
          ),
        ),
      ),
    );
  }
}

/// The waiting bar. Its own [StatefulWidget] so the controller is created and
/// disposed outside anyone's `build`.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.finishing, this.onFinished});

  final bool finishing;
  final VoidCallback? onFinished;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  /// The controller's value IS the fill fraction, so waiting and finishing
  /// are two `animateTo`s on one timeline and finishing starts wherever the
  /// wait had reached.
  late final AnimationController _controller = AnimationController(vsync: this);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once: this runs again whenever an ancestor changes (e.g. text size).
    if (_started) return;
    _started = true;

    if (widget.finishing) {
      _finish();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: a still bar, and no ticker burning frames.
      _controller.value = _barWaitingTarget;
    } else {
      _controller.animateTo(
        _barWaitingTarget,
        duration: _barWaitingDuration,
        curve: const _ApproachCurve(_barApproachRate),
      );
    }
  }

  @override
  void didUpdateWidget(_ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.finishing && !oldWidget.finishing) _finish();
  }

  void _finish() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      // After this frame: the callback rebuilds the caller, which must not
      // happen while it is still building.
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFinished());
      return;
    }
    // A TickerFuture never completes if the controller is stopped or
    // disposed first, so a halted bar never reports finishing.
    _controller
        .animateTo(1, duration: _barFinishDuration, curve: Curves.easeOut)
        .then((_) => _notifyFinished());
  }

  void _notifyFinished() {
    if (mounted) widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Excluded from semantics: the page's own live region announces the wait,
    // and a bar that is not a real completion figure must not be read as one.
    return ExcludeSemantics(
      child: Container(
        width: _barWidth,
        height: _barHeight,
        decoration: BoxDecoration(
          color: colors.onBrand.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(_barRadius),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: AlignmentDirectional.centerStart,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => FractionallySizedBox(
            widthFactor: _controller.value,
            // The track's `alignment` loosens the height to 0..8, and a
            // childless box takes the smallest — without this the fill is 0 px
            // tall and never shows.
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.mint,
                borderRadius: BorderRadius.circular(_barRadius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fast at first, then ever slower, and exactly 1 at the end: an exponential
/// approach normalised to finish on the target. [rate] sets how early it
/// flattens (higher = sooner).
class _ApproachCurve extends Curve {
  const _ApproachCurve(this.rate);

  final double rate;

  @override
  double transformInternal(double t) =>
      (1 - math.exp(-rate * t)) / (1 - math.exp(-rate));
}
