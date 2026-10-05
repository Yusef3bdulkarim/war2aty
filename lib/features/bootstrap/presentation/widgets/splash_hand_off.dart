import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How long the rings take to come to rest before the app is built
/// (F27-P01, "settle, then reveal").
const Duration kSplashSettleDuration = Duration(milliseconds: 350);

/// How long the splash takes to fade off the app.
const Duration kSplashExitDuration = Duration(milliseconds: 400);

/// The same, under reduced motion: a short plain fade.
const Duration kSplashExitDurationReduced = Duration(milliseconds: 150);

/// The longest the motionless splash waits for the app's first screen to
/// report its content before revealing it anyway.
const Duration kSplashRevealCap = Duration(milliseconds: 600);

/// Hands the launch over from the splash to the app without a visible stall
/// (F27-P01).
///
/// Measured on a mid-range phone, the app's first screen costs two long
/// frames: its first build (~55 ms) and, a moment later, the rebuild when its
/// data arrives (~100 ms). Any animation on screen at those moments freezes.
/// So nothing moves while they happen:
///
/// 1. **Settle** — once [app] exists, the splash's rings ease to a stop over
///    [kSplashSettleDuration] (it reads that through [SplashPhases]) and its
///    clock stops.
/// 2. **Build, hidden** — only then is the app mounted, under the motionless,
///    opaque splash. Frame by frame, the hand-off waits until
///    [isContentReady] says the first screen has its content, or
///    [kSplashRevealCap] has passed.
/// 3. **Reveal** — the splash fades off over [kSplashExitDuration], its parts
///    following [SplashPhases.exit], and leaves the tree; then [onRevealed].
///
/// Under reduced motion there is nothing to settle, and the reveal is a short
/// plain fade. Both layers keep their state throughout (keyed): the splash's
/// animation never restarts and the app is never rebuilt from scratch. From
/// the start of the reveal the splash ignores touches and screen readers.
class SplashHandOff extends StatefulWidget {
  const SplashHandOff({
    super.key,
    required this.splash,
    this.app,
    this.isContentReady,
    this.onRevealed,
  });

  /// Shown from launch until the reveal has finished.
  final Widget splash;

  /// The app, once launch is done; `null` until then.
  final Widget? app;

  /// Whether the app's first screen has its content. `null` means it is
  /// ready as soon as it is built.
  final bool Function()? isContentReady;

  /// Called once, when the splash has left.
  final VoidCallback? onRevealed;

  @override
  State<SplashHandOff> createState() => _SplashHandOffState();
}

enum _Phase { splash, settling, building, revealing, done }

class _SplashHandOffState extends State<SplashHandOff>
    with TickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: kSplashSettleDuration,
  )..addStatusListener(_onSettleStatus);

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: kSplashExitDuration,
  )..addStatusListener(_onExitStatus);

  late final CurvedAnimation _exitCurve = CurvedAnimation(
    parent: _exit,
    curve: Curves.easeOutCubic,
  );

  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(_exitCurve);

  _Phase _phase = _Phase.splash;

  /// Frame time of the first frame with the app mounted, for the cap.
  Duration? _buildStartedAt;

  bool get _reducedMotion =>
      MediaQueryData.fromView(View.of(context)).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Launch can already be done by the time the hand-off first appears.
    if (_phase == _Phase.splash && widget.app != null) _startSettle();
  }

  @override
  void didUpdateWidget(SplashHandOff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.app == null) {
      // Not expected — launch never goes back — but if the app is withdrawn,
      // the splash must be there to cover it.
      _phase = _Phase.splash;
      _buildStartedAt = null;
      _settle.reset();
      _exit.reset();
      return;
    }
    if (_phase == _Phase.splash) _startSettle();
  }

  /// Always called from inside a build (`didChangeDependencies`,
  /// `didUpdateWidget`), which picks up any phase it sets.
  void _startSettle() {
    if (_reducedMotion) {
      // Nothing is moving, so there is nothing to wait for.
      _mountApp(inBuild: true);
      return;
    }
    _phase = _Phase.settling;
    _settle.forward();
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _phase == _Phase.settling) {
      _mountApp(inBuild: false);
    }
  }

  void _mountApp({required bool inBuild}) {
    if (inBuild) {
      _phase = _Phase.building;
    } else {
      setState(() => _phase = _Phase.building);
    }
    _onNextFrame(_awaitContent);
  }

  /// Runs after every frame while the app is mounted under the splash, until
  /// its first screen has its content or the cap runs out.
  void _awaitContent(Duration frameTime) {
    if (!mounted || _phase != _Phase.building) return;
    final startedAt = _buildStartedAt ??= frameTime;
    final ready = widget.isContentReady?.call() ?? true;
    if (ready || frameTime - startedAt >= kSplashRevealCap) {
      _startReveal();
    } else {
      _onNextFrame(_awaitContent);
    }
  }

  void _startReveal() {
    _exit.duration = _reducedMotion
        ? kSplashExitDurationReduced
        : kSplashExitDuration;
    setState(() => _phase = _Phase.revealing);
    _exit.forward();
  }

  void _onExitStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() => _phase = _Phase.done);
    widget.onRevealed?.call();
  }

  /// [then] after the next frame, asking for that frame.
  static void _onNextFrame(FrameCallback then) {
    SchedulerBinding.instance
      ..addPostFrameCallback(then)
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _exitCurve.dispose();
    _exit.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final showApp =
        app != null &&
        (_phase == _Phase.building ||
            _phase == _Phase.revealing ||
            _phase == _Phase.done);
    final revealing = _phase == _Phase.revealing;

    // Keys keep each layer's state when the other one comes or goes. The
    // alignment is not directional: there is no Directionality above the apps.
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (showApp)
          KeyedSubtree(
            key: const ValueKey('app'),
            child: RepaintBoundary(child: app),
          ),
        if (_phase != _Phase.done)
          KeyedSubtree(
            key: const ValueKey('splash'),
            child: IgnorePointer(
              ignoring: revealing,
              child: ExcludeSemantics(
                excluding: revealing,
                child: FadeTransition(
                  opacity: _opacity,
                  child: SplashPhases(
                    settle: _settle,
                    exit: _exitCurve,
                    // The splash repaints every frame; the app under it
                    // should not have to.
                    child: RepaintBoundary(child: widget.splash),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The hand-off's two phases, for the splash's own parts to play along.
///
/// [settle] runs 0 → 1 linearly while the rings come to rest; [exit] runs
/// 0 → 1, already eased, while the splash fades off the app (the mark grows a
/// little, the rings spread). Outside a [SplashHandOff] both stay at 0.
class SplashPhases extends InheritedWidget {
  const SplashPhases({
    super.key,
    required this.settle,
    required this.exit,
    required super.child,
  });

  final Animation<double> settle;
  final Animation<double> exit;

  static ({Animation<double> settle, Animation<double> exit}) of(
    BuildContext context,
  ) {
    final scope = context.dependOnInheritedWidgetOfExactType<SplashPhases>();
    return (
      settle: scope?.settle ?? kAlwaysDismissedAnimation,
      exit: scope?.exit ?? kAlwaysDismissedAnimation,
    );
  }

  @override
  bool updateShouldNotify(SplashPhases oldWidget) =>
      oldWidget.settle != settle || oldWidget.exit != exit;
}
