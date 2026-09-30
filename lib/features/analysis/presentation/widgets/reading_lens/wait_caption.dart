import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import 'lens_timeline.dart';

const double _captionGap = 6;
const Duration _switch = Duration(milliseconds: 450);
const double _slide = 12;

/// Two lines of the caption at its size, so a caption change never moves the
/// page; a longer one (Large Text) still grows the block (F22 #14).
const double _captionMinHeight = 66;

/// The wait page's words under the paper: what is being looked for, and a
/// line that says there is nothing to do (F22 #7).
///
/// Follows the clock from when it first appears, on one-shot [Timer]s at
/// [LensTimeline.stepStarts] — the same moments the lens moves between the
/// paper's parts. [onLongWait] fires once, at [LensTimeline.longWaitAt].
/// Set [finished] once the result has arrived: the caption says so and the
/// clock stops.
///
/// Decorative for assistive technology: the page announces the wait itself,
/// and captions on a timer are not news worth reading out (F22 #13).
class WaitCaption extends StatefulWidget {
  const WaitCaption({this.finished = false, this.onLongWait, super.key});

  final bool finished;
  final VoidCallback? onLongWait;

  @override
  State<WaitCaption> createState() => _WaitCaptionState();
}

class _WaitCaptionState extends State<WaitCaption> {
  int _step = 0;
  final List<Timer> _timers = [];

  static final int _longHintStep = LensTimeline.stepAt(
    LensTimeline.longSublineAt,
  );
  static final int _longWaitStep = LensTimeline.stepAt(LensTimeline.longWaitAt);

  @override
  void initState() {
    super.initState();
    if (widget.finished) return;
    for (final (step, at) in LensTimeline.stepStarts.indexed.skip(1)) {
      _timers.add(
        Timer(Duration(milliseconds: (at * 1000).round()), () {
          if (!mounted) return;
          setState(() => _step = step);
          if (step == _longWaitStep) widget.onLongWait?.call();
        }),
      );
    }
  }

  @override
  void didUpdateWidget(WaitCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.finished && !oldWidget.finished) _stopClock();
  }

  void _stopClock() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _stopClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = AppColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final finished = widget.finished;

    final caption = finished ? strings.analysisWaitReady : _caption(strings);
    final hint = finished
        ? strings.analysisWaitHintReady
        : _step >= _longHintStep
        ? strings.analysisWaitHintLong
        : strings.analysisWaitHint;

    final captionStyle = AppTypography.headlineMedium.copyWith(
      color: colors.ink,
      height: 1.5,
    );

    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _captionMinHeight),
            child: _Switcher(
              still: still,
              child: Text.rich(
                key: ValueKey(caption),
                TextSpan(
                  text: caption,
                  children: [
                    if (!finished)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: _PulsingDots(
                          style: captionStyle.copyWith(
                            color: colors.brandPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: captionStyle,
              ),
            ),
          ),
          const SizedBox(height: _captionGap),
          _Switcher(
            still: still,
            child: Text(
              hint,
              key: ValueKey(hint),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.medium,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _caption(AppStrings strings) => switch (_step) {
    0 => strings.analysisWaitStepType,
    1 => strings.analysisWaitStepActions,
    2 => strings.analysisWaitStepDates,
    3 => strings.analysisWaitStillSeconds,
    4 => strings.analysisWaitReviewing,
    _ => strings.analysisWaitTakingLonger,
  };
}

/// Crossfades a changed line in place: the new one rises 12 px as it fades
/// in, the old one fades out where it was. Under reduced motion, a fade only.
class _Switcher extends StatelessWidget {
  const _Switcher({required this.still, required this.child});

  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _switch,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (still) return fade;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _slide * (1 - animation.value)),
            child: child,
          ),
          child: fade,
        );
      },
      child: child,
    );
  }
}

/// Three dots that brighten one after another, so the caption keeps moving
/// between changes. Still, and fully drawn, under reduced motion.
class _PulsingDots extends StatefulWidget {
  const _PulsingDots({required this.style});

  /// The caption's own style, in the dots' colour: a widget inside a text
  /// span does not inherit the span's style.
  final TextStyle style;

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 1200);

  /// Each dot's start within the period, and how far it lifts.
  static const List<double> _offsets = [0, 1 / 6, 1 / 3];
  static const double _lift = 3;

  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller?.dispose();
      _controller = null;
    } else {
      _controller ??= AnimationController(vsync: this, duration: _period)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final controller = _controller;
    if (controller == null) return Text('...', style: style);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final start in _offsets)
            _dot(style, _pulse((controller.value - start) % 1)),
        ],
      ),
    );
  }

  Widget _dot(TextStyle style, double pulse) => Transform.translate(
    offset: Offset(0, -_lift * pulse),
    child: Opacity(
      opacity: 0.25 + 0.75 * pulse,
      child: Text('.', style: style),
    ),
  );

  /// Up to full at 40% of a dot's turn, back down by its end.
  static double _pulse(double u) => u < 0.4 ? u / 0.4 : (1 - u) / 0.6;
}
