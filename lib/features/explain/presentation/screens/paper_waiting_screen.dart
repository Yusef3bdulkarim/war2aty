import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

const double _paperWidth = 190;
const double _paperHeight = 250;
const double _paperTiltRadians = -3 * math.pi / 180;

class PaperWaitingScreen extends StatelessWidget {
  const PaperWaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _WaitingPaper(),
                const SizedBox(height: 40),
                _WaitingVoice(sentence: context.strings.paperWaitingSentence),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingPaper extends StatelessWidget {
  const _WaitingPaper();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: _paperWidth,
        height: _paperHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: _paperTiltRadians,
                child: const _PaperCard(),
              ),
            ),
            const _ScanLine(),
          ],
        ),
      ),
    );
  }
}

class _PaperLine {
  const _PaperLine(
    this.height,
    this.widthFactor, {
    this.tinted = false,
    this.extraGapBefore = false,
  });

  final double height;
  final double widthFactor;
  final bool tinted;
  final bool extraGapBefore;
}

const List<_PaperLine> _paperLines = [
  _PaperLine(9, 0.5, tinted: true),
  _PaperLine(5, 1),
  _PaperLine(5, 0.85),
  _PaperLine(5, 1),
  _PaperLine(5, 0.65),
  _PaperLine(5, 1, extraGapBefore: true),
  _PaperLine(5, 0.90),
  _PaperLine(5, 0.55),
  _PaperLine(5, 1, extraGapBefore: true),
  _PaperLine(5, 0.70),
];

class _PaperCard extends StatelessWidget {
  const _PaperCard();

  static const double _innerWidth = _paperWidth - 2 * 20;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final children = <Widget>[];
    for (final (index, line) in _paperLines.indexed) {
      if (index > 0) {
        children.add(SizedBox(height: line.extraGapBefore ? 20 : 10));
      }
      children.add(
        DecoratedBox(
          decoration: BoxDecoration(
            color: line.tinted
                ? colors.brandPrimary.withValues(alpha: 0.55)
                : colors.borderStrong,
            borderRadius: BorderRadius.circular(3),
          ),
          child: SizedBox(
            width: _innerWidth * line.widthFactor,
            height: line.height,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.borderCool),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  static const double _topAt = _paperHeight * 0.06;
  static const double _bottomAt = _paperHeight * 0.90;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final top =
            _topAt +
            (_bottomAt - _topAt) * math.sin(math.pi * _controller.value);
        return Positioned(
          left: -10,
          right: -10,
          top: top,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: colors.mint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

class _WaitingVoice extends StatelessWidget {
  const _WaitingVoice({required this.sentence});

  final String sentence;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _VoiceCapsule(),
        const SizedBox(height: 14),
        Text(
          sentence,
          textAlign: TextAlign.center,
          style: AppTypography.titleAction.copyWith(color: colors.ink),
        ),
        const SizedBox(height: 14),
        const _WaitingDots(),
      ],
    );
  }
}

class _VoiceCapsule extends StatelessWidget {
  const _VoiceCapsule();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceTealAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StrokeIcon(
              StrokeGlyph.speaker,
              color: colors.brandPrimary,
              strokeWidth: 2,
            ),
            const SizedBox(width: 12),
            const _WaveBars(),
          ],
        ),
      ),
    );
  }
}

class _WaveBars extends StatefulWidget {
  const _WaveBars();

  @override
  State<_WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<_WaveBars>
    with SingleTickerProviderStateMixin {
  static const List<double> _delays = [0, .15, .3, .45, .6];
  static const double _minScale = 0.35;
  static const double _barHeight = 22;

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, delay) in _delays.indexed) ...[
            if (index > 0) const SizedBox(width: 4),
            _bar(colors.brandPrimary, delay),
          ],
        ],
      ),
    );
  }

  Widget _bar(Color color, double delay) {
    final phase = (_controller.value + delay) % 1;
    final triangle = phase < 0.5 ? phase / 0.5 : (1 - phase) / 0.5;
    final scale = _minScale + (1 - _minScale) * triangle;
    return Container(
      width: 4,
      height: _barHeight * scale,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _WaitingDots extends StatefulWidget {
  const _WaitingDots();

  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots>
    with SingleTickerProviderStateMixin {
  static const List<double> _delays = [0, 1 / 6, 1 / 3];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, delay) in _delays.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              _dot(colors.brandPrimary, delay),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color, double delay) {
    final phase = (_controller.value + delay) % 1;
    final pulse = phase < 0.5 ? phase / 0.5 : (1 - phase) / 0.5;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25 + 0.75 * pulse),
        shape: BoxShape.circle,
      ),
    );
  }
}
