import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// How long one pass of the shimmer takes.
const Duration _shimmerPeriod = Duration(milliseconds: 1400);

/// A placeholder block standing in for content that has not loaded.
///
/// Draws nothing but a rounded grey box — the movement comes from a [Shimmer]
/// ancestor, so a whole section animates as one instead of each box running
/// its own controller.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    required this.height,
    this.radius = 8,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Sweeps a soft highlight across its subtree while content loads.
///
/// One controller drives the whole subtree, and it is stopped and disposed
/// with the widget — a repeating animation that outlives its screen keeps the
/// device awake redrawing frames nobody sees.
///
/// Honours the platform's "reduce motion" setting: when animations are
/// disabled the placeholders are shown still rather than pulsing, which
/// matters for users who find movement uncomfortable.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, this.label, super.key});

  final Widget child;

  /// Announced to assistive technology in place of the placeholder shapes,
  /// which mean nothing when read aloud.
  final String? label;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  // Built eagerly in initState, never lazily: a `late final` field that only
  // some build paths touch can end up being constructed *by* dispose(), which
  // then looks up an ancestor on an already-deactivated element.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _shimmerPeriod);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also keeps the ticker idle under reduced motion rather than burning
    // frames on an animation that is never painted.
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
    const colors = AppColors.light;

    final placeholders = ExcludeSemantics(child: widget.child);
    final content = widget.label == null
        ? placeholders
        : Semantics(label: widget.label, liveRegion: true, child: placeholders);

    if (MediaQuery.disableAnimationsOf(context)) return content;

    return AnimatedBuilder(
      animation: _controller,
      // The subtree does not depend on the animation, so it is built once and
      // reused on every tick rather than rebuilt 60 times a second.
      child: content,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [colors.surfaceAlt, colors.card, colors.surfaceAlt],
          // Slide a narrow highlight from one edge to the other.
          stops: _stopsFor(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }

  /// Three rising stops that travel together across the 0..1 range.
  List<double> _stopsFor(double t) {
    final centre = t * 2 - 0.5;
    return [
      (centre - 0.3).clamp(0.0, 1.0),
      centre.clamp(0.0, 1.0),
      (centre + 0.3).clamp(0.0, 1.0),
    ];
  }
}
