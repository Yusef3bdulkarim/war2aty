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

/// The design's `wqbar`: the fill runs from 6% to 96% and stops there.
const double _barFrom = 0.06;
const double _barTo = 0.96;
const Duration _barDuration = Duration(milliseconds: 2400);

/// The full-bleed page shown while the analysis service is working.
///
/// It says what is being prepared rather than naming a step: the user is
/// waiting on their paper being understood, not on a pipeline (UX rule §5.13 —
/// no technical terms). The bar is deliberately not a completion percentage —
/// it eases towards, and stops short of, full while the wait lasts.
class AnalysisProgressView extends StatelessWidget {
  const AnalysisProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
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
              const _ProgressBar(),
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
  const _ProgressBar();

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _barDuration,
  )..forward();

  late final Animation<double> _fill = Tween<double>(
    begin: _barFrom,
    end: _barTo,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

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
          animation: _fill,
          builder: (context, _) => FractionallySizedBox(
            widthFactor: _fill.value,
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
