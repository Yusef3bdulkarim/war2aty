import 'package:flutter/material.dart';

/// The design's launch progress indicator: three dots pulsing in sequence
/// (9px, 1.2s cycle, staggered by 0.2s).
class PulsingDots extends StatefulWidget {
  const PulsingDots({this.color = Colors.white, this.size = 9, super.key});

  final Color color;
  final double size;

  @override
  State<PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Stagger each dot by 0.2s of the 1.2s cycle.
              final t = (_controller.value + i * (0.2 / 1.2)) % 1.0;
              // 0.4 -> 1.0 -> 0.4 opacity, matching the design's pulse.
              final opacity = 0.4 + 0.6 * (1 - (2 * t - 1).abs());
              return Opacity(opacity: opacity, child: child);
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
