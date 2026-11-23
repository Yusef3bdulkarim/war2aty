import 'package:flutter/material.dart';

import '../../../../core/audio/reading_speed.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/paper_player_view.dart';

const double _paddingH = 16;
const double _paddingV = 12;
const double _rowGap = 12;
const double _buttonSize = 56;
const double _buttonIconSize = 28;
const double _waveformHeight = 30;
const double _barGap = 2;
const double _barRadius = 2;
const double _clockGap = 4;
const double _clockFontSize = 12;
const double _speedMinWidth = 52;
const double _speedMinHeight = 40;
const double _speedFontSize = 15;
const List<double> _barHeights = [
  8,
  14,
  20,
  12,
  24,
  18,
  10,
  22,
  16,
  26,
  12,
  20,
  14,
  8,
  18,
  24,
  10,
  16,
  22,
  12,
  20,
  14,
  26,
  10,
  18,
  12,
  22,
  16,
  8,
  14,
];
const double _minBarScale = 0.35;
const double _barPhaseStep = 0.07;
const Duration _waveCycle = Duration(milliseconds: 1000);

class PaperPlayerBar extends StatelessWidget {
  const PaperPlayerBar({
    required this.view,
    required this.speed,
    this.onPressed,
    this.onSeek,
    this.onSpeedTap,
    super.key,
  });

  final PaperPlayerView view;
  final ReadingSpeed speed;
  final VoidCallback? onPressed;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onSpeedTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.borderSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingH,
          vertical: _paddingV,
        ),
        child: Row(
          children: [
            _ActionButton(view: view, onPressed: onPressed),
            const SizedBox(width: _rowGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Waveform(view: view, onSeek: onSeek),
                  const SizedBox(height: _clockGap),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ExcludeSemantics(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          view.clock,
                          key: const ValueKey('paper-player-clock'),
                          style: AppTypography.labelCard.copyWith(
                            fontSize: _clockFontSize,
                            fontWeight: AppTypography.bold,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _rowGap),
            _SpeedPill(speed: speed, onTap: onSpeedTap),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.view, required this.onPressed});

  final PaperPlayerView view;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final enabled = view.enabled && onPressed != null;
    final dimmed = !enabled && !view.preparing;
    final label = switch (view.action) {
      _ when view.preparing => strings.paperPlayerPreparingLabel,
      PaperPlayerAction.pause => strings.audioReaderPauseLabel,
      PaperPlayerAction.resume => strings.audioReaderResumeLabel,
      PaperPlayerAction.replay => strings.paperPlayerReplayLabel,
    };
    final icon = switch (view.action) {
      PaperPlayerAction.pause => Icons.pause_rounded,
      PaperPlayerAction.resume => Icons.play_arrow_rounded,
      PaperPlayerAction.replay => Icons.replay_rounded,
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Material(
        key: const ValueKey('paper-player-button'),
        color: dimmed
            ? colors.brandPrimary.withValues(alpha: 0.4)
            : colors.brandPrimary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox.square(
            dimension: _buttonSize,
            child: Center(
              child: view.preparing
                  ? SizedBox.square(
                      dimension: _buttonIconSize - 4,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colors.onBrand,
                      ),
                    )
                  : Icon(icon, size: _buttonIconSize, color: colors.onBrand),
            ),
          ),
        ),
      ),
    );
  }
}

class _Waveform extends StatefulWidget {
  const _Waveform({required this.view, required this.onSeek});

  final PaperPlayerView view;
  final ValueChanged<double>? onSeek;

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _waveCycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldRun =
        widget.view.animated && !MediaQuery.disableAnimationsOf(context);
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _seekAt(double dx, double width) {
    final onSeek = widget.onSeek;
    if (onSeek == null || width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    onSeek(rtl ? 1 - fraction : fraction);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final view = widget.view;
    final fill = view.fill;
    final playedBars = fill == null
        ? _barHeights.length
        : (fill * _barHeights.length).floor();
    final seekable = view.canSeek && widget.onSeek != null;

    return Semantics(
      label: context.strings.paperPlayerWaveformLabel,
      value: view.clock,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          key: const ValueKey('paper-player-waveform'),
          behavior: HitTestBehavior.opaque,
          onTapUp: seekable
              ? (details) =>
                    _seekAt(details.localPosition.dx, constraints.maxWidth)
              : null,
          child: SizedBox(
            height: _waveformHeight,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                children: [
                  for (final (index, height) in _barHeights.indexed) ...[
                    if (index > 0) const SizedBox(width: _barGap),
                    Expanded(
                      child: Center(
                        child: Container(
                          key: ValueKey('paper-player-bar-$index'),
                          height: height * _scaleFor(index),
                          decoration: BoxDecoration(
                            color: index < playedBars
                                ? colors.brandPrimary
                                : colors.borderStrong,
                            borderRadius: BorderRadius.circular(_barRadius),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _scaleFor(int index) {
    if (!_controller.isAnimating) return 1;
    final phase = (_controller.value + index * _barPhaseStep) % 1;
    final triangle = phase < 0.5 ? phase / 0.5 : (1 - phase) / 0.5;
    return _minBarScale + (1 - _minBarScale) * triangle;
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.speed, required this.onTap});

  final ReadingSpeed speed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: strings.paperPlayerSpeedLabel,
      value: speed.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: const ValueKey('paper-player-speed'),
        color: colors.surfaceTeal,
        shape: StadiumBorder(side: BorderSide(color: colors.borderCool)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _speedMinWidth,
              minHeight: _speedMinHeight,
            ),
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    speed.label,
                    style: AppTypography.labelCard.copyWith(
                      fontSize: _speedFontSize,
                      fontWeight: AppTypography.extraBold,
                      color: colors.brandDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
