import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How long the motionless launch screen waits for the first screen to report
/// its content before revealing it anyway.
///
/// An escape hatch, not a schedule: a screen that never reports would
/// otherwise strand the user on the mark forever.
const Duration kLaunchRevealCap = Duration(milliseconds: 600);

/// How long the launch screen takes to fade off the app.
const Duration kLaunchRevealDuration = Duration(milliseconds: 300);

/// The same, under reduced motion.
const Duration kLaunchRevealDurationReduced = Duration(milliseconds: 120);

/// Hands the launch over from the launch screen to the app without a cut
/// (F28-T07).
///
/// Rebuilt from nothing to replace `SplashHandOff`, which is gone with the
/// splash it was built around. Two of the four phases went with it: there is
/// no entrance to wait out and no animation to settle, because the launch
/// screen does not move.
///
/// What remains is the part that was never about the animation. Measured on a
/// mid-range phone, the app's first screen costs two long frames — its first
/// build (~55 ms) and the rebuild when its data arrives (~100 ms) — and
/// revealing before those land shows the user a half-drawn Home. So:
///
/// 1. **Build, hidden.** Once [app] exists it is mounted *under* the still
///    opaque launch screen. Frame by frame, the hand-off waits until
///    [isContentReady] says the first screen has its content, or
///    [kLaunchRevealCap] runs out.
/// 2. **Reveal.** The launch screen fades off over [kLaunchRevealDuration] and
///    leaves the tree; then [onRevealed].
///
/// Both layers keep their state throughout (keyed), so the app is never built
/// twice. From the start of the reveal the launch screen ignores touches and
/// screen readers.
///
/// **There is deliberately no minimum display time.** The plan for F28 carried
/// a ~500 ms floor, on the reasoning that a splash appearing and vanishing too
/// quickly reads as a glitch. That reasoning does not survive F28-T05: the
/// native splash now draws this same frame, pixel for pixel, from ~100 ms, so
/// there is no moment at which the launch screen *appears*. The user sees one
/// continuous image, and a floor here would only hold it in place after the
/// app behind it was ready. The launch is therefore as short as the work
/// allows, which is what a floor would have been trading away.
class LaunchHandOff extends StatefulWidget {
  const LaunchHandOff({
    super.key,
    required this.launchScreen,
    this.app,
    this.isContentReady,
    this.onRevealed,
  });

  /// Shown from the first frame until the reveal has finished.
  final Widget launchScreen;

  /// The app, once launch is done; `null` until then.
  final Widget? app;

  /// Whether the app's first screen has its content. `null` means it is ready
  /// as soon as it is built.
  final bool Function()? isContentReady;

  /// Called once, when the launch screen has left.
  final VoidCallback? onRevealed;

  @override
  State<LaunchHandOff> createState() => _LaunchHandOffState();
}

enum _Phase { launching, building, revealing, done }

class _LaunchHandOffState extends State<LaunchHandOff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: kLaunchRevealDuration,
  )..addStatusListener(_onRevealStatus);

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOut,
  );

  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(_curve);

  _Phase _phase = _Phase.launching;

  /// Frame time of the first frame with the app mounted, for the cap.
  Duration? _buildStartedAt;

  bool get _reducedMotion =>
      MediaQueryData.fromView(View.of(context)).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Launch can already be done by the time the hand-off first appears.
    if (_phase == _Phase.launching && widget.app != null) _mountApp();
  }

  @override
  void didUpdateWidget(LaunchHandOff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.app == null) {
      // Not expected — launch never goes back — but if the app is withdrawn,
      // the launch screen must be there to cover it.
      _phase = _Phase.launching;
      _buildStartedAt = null;
      _reveal.reset();
      return;
    }
    if (_phase == _Phase.launching) _mountApp();
  }

  /// Always called from inside a build (`didChangeDependencies`,
  /// `didUpdateWidget`), which picks up the phase it sets without `setState`.
  void _mountApp() {
    _phase = _Phase.building;
    _onNextFrame(_awaitContent);
  }

  /// Runs after every frame while the app is mounted under the launch screen,
  /// until its first screen has its content or the cap runs out.
  void _awaitContent(Duration frameTime) {
    if (!mounted || _phase != _Phase.building) return;
    final startedAt = _buildStartedAt ??= frameTime;
    final ready = widget.isContentReady?.call() ?? true;
    if (ready || frameTime - startedAt >= kLaunchRevealCap) {
      _startReveal();
    } else {
      _onNextFrame(_awaitContent);
    }
  }

  void _startReveal() {
    _reveal.duration = _reducedMotion
        ? kLaunchRevealDurationReduced
        : kLaunchRevealDuration;
    setState(() => _phase = _Phase.revealing);
    _reveal.forward();
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() => _phase = _Phase.done);
    widget.onRevealed?.call();
  }

  /// [then] after the next frame, asking for that frame. Without the request,
  /// a launch that finishes while nothing else is repainting would wait for
  /// something unrelated to schedule one.
  static void _onNextFrame(FrameCallback then) {
    SchedulerBinding.instance
      ..addPostFrameCallback(then)
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _curve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final showApp = app != null && _phase != _Phase.launching;
    final revealing = _phase == _Phase.revealing;

    // `Alignment`, not the directional default: there is no `Directionality`
    // above the two apps, and `AlignmentDirectional` would need one.
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (showApp)
          KeyedSubtree(
            key: const ValueKey('app'),
            // The launch screen composites over this for the length of the
            // fade; the app under it should not repaint for that.
            child: RepaintBoundary(child: app),
          ),
        if (_phase != _Phase.done)
          KeyedSubtree(
            key: const ValueKey('launch'),
            child: IgnorePointer(
              ignoring: revealing,
              child: ExcludeSemantics(
                excluding: revealing,
                child: FadeTransition(
                  opacity: _opacity,
                  child: widget.launchScreen,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
