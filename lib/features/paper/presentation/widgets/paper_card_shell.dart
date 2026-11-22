import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

const double _iconSize = 40;
const double _iconRadius = 12;
const double _iconGlyphSize = 22;
const double _iconStrokeWidth = 2;
const double _headerGap = 10;
const double _bodyGap = 10;
const double _normalBorderWidth = 1.0;
const double _highlightBorderWidth = 2.0;
const double _paddingBase = 19;
const double _titleFontSize = 15;

class PaperCardShell extends StatelessWidget {
  const PaperCardShell({
    required this.icon,
    required this.title,
    required this.titleColor,
    required this.background,
    required this.borderColor,
    required this.iconBackground,
    required this.iconColor,
    required this.child,
    this.isHighlighted = false,
    super.key,
  });

  final StrokeGlyph icon;
  final String title;
  final Color titleColor;
  final Color background;
  final Color borderColor;
  final Color iconBackground;
  final Color iconColor;
  final bool isHighlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final borderWidth = isHighlighted
        ? _highlightBorderWidth
        : _normalBorderWidth;
    final resolvedBackground = isHighlighted ? colors.surfaceTeal : background;
    final resolvedBorderColor = isHighlighted
        ? colors.brandPrimary
        : borderColor;
    final resolvedIconBackground = isHighlighted
        ? colors.brandPrimary
        : iconBackground;
    final resolvedIconColor = isHighlighted ? colors.onBrand : iconColor;

    return Container(
      key: const ValueKey('paper-card-shell'),
      decoration: BoxDecoration(
        color: resolvedBackground,
        border: Border.all(color: resolvedBorderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      padding: EdgeInsets.all(_paddingBase - borderWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                key: const ValueKey('paper-card-icon-box'),
                width: _iconSize,
                height: _iconSize,
                decoration: BoxDecoration(
                  color: resolvedIconBackground,
                  borderRadius: BorderRadius.circular(_iconRadius),
                ),
                child: Center(
                  child: StrokeIcon(
                    icon,
                    color: resolvedIconColor,
                    size: _iconGlyphSize,
                    strokeWidth: _iconStrokeWidth,
                  ),
                ),
              ),
              const SizedBox(width: _headerGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.labelCard.copyWith(
                      fontSize: _titleFontSize,
                      fontWeight: AppTypography.extraBold,
                      color: titleColor,
                    ),
                  ),
                ),
              ),
              if (isHighlighted) ...[
                const SizedBox(width: _headerGap),
                _SpeakingIndicator(
                  label: context.strings.paperCardSpeakingLabel,
                ),
              ],
            ],
          ),
          const SizedBox(height: _bodyGap),
          child,
        ],
      ),
    );
  }
}

class _SpeakingIndicator extends StatefulWidget {
  const _SpeakingIndicator({required this.label});

  final String label;

  @override
  State<_SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<_SpeakingIndicator>
    with SingleTickerProviderStateMixin {
  static const List<double> _delays = [0, .2, .4];
  static const double _minScale = 0.35;
  static const double _barWidth = 3;
  static const double _barHeight = 14;
  static const double _barGap = 3;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, delay) in _delays.indexed) ...[
              if (index > 0) const SizedBox(width: _barGap),
              _bar(colors.brandPrimary, delay),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, double delay) {
    final phase = (_controller.value + delay) % 1;
    final triangle = phase < 0.5 ? phase / 0.5 : (1 - phase) / 0.5;
    final scale = _minScale + (1 - _minScale) * triangle;
    return Container(
      width: _barWidth,
      height: _barHeight * scale,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
