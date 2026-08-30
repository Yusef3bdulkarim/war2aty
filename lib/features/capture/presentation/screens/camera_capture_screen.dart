import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/unit_rect.dart';
import '../capture_palette.dart';
import '../cubit/camera_capture_cubit.dart';
import '../cubit/camera_capture_state.dart';
import '../widgets/viewfinder_frame.dart';

// From `Waraqti.dc.html` → `camera`.
const double _controlBox = 42;
const double _shutterOuter = 80;
const double _shutterInner = 64;
const double _hintRadius = 20;

/// The viewfinder: a live camera feed, a framing guide, and one shutter button
/// that produces a single portrait photo.
///
/// The screen owns the app-lifecycle wiring — the camera is released when the
/// app goes to the background and re-opened on return, so it is never held
/// while another app or the lock screen needs it.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    required this.onCaptured,
    required this.onClose,
    super.key,
  });

  /// Hands the finished photo to the next stage (crop / review, F03-T04+).
  final ValueChanged<CapturedPhoto> onCaptured;

  /// Leaves the capture flow.
  final VoidCallback onClose;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver, RouteAware {
  /// Sits on the guide box inside [ViewfinderFrame]. Used with [_previewKey]
  /// to measure the guide box's position as a fraction of what the camera
  /// actually captured (F15-T03).
  final GlobalKey _frameKey = GlobalKey();

  /// Wraps the live preview widget itself, so its real rendered rect (after
  /// `CameraPreview`'s internal aspect-ratio fit) can be measured.
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<CameraCaptureCubit>().start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<CameraCaptureCubit>();
    switch (state) {
      case AppLifecycleState.resumed:
        cubit.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        cubit.suspend();
    }
  }

  /// Fires when a route pushed on top of this one (the crop/preview screen,
  /// or — via a "retake" that replaced it — the OCR/OCR-review screen) is
  /// popped back to it. A finished capture leaves the cubit parked on the
  /// terminal [CameraCaptured] state, which the viewfinder does not treat as
  /// ready; without this, the screen is stuck showing its last frame (or the
  /// "opening camera" spinner) forever, since nothing else re-arms it once
  /// in-app navigation — as opposed to the app itself being backgrounded —
  /// reveals it again.
  @override
  void didPopNext() {
    context.read<CameraCaptureCubit>().start();
  }

  /// Measures the guide box, then fires the shutter.
  void _capture() {
    context.read<CameraCaptureCubit>().capture(guideBox: _measureGuideBox());
  }

  /// The guide box's position as a fraction of the live preview's own
  /// rendered rect — not the whole screen — so the crop lines up with what
  /// was actually captured regardless of screen size or how `CameraPreview`
  /// fits its feed inside the available space.
  ///
  /// Both rects are read off the real render tree, so the crop follows the
  /// guide box wherever and at whatever size it ends up (F15-T12) rather than
  /// re-deriving it from constants that then have to be kept in sync.
  ///
  /// Falls back to [UnitRect.full] (skips the crop) if either box hasn't
  /// been laid out yet or has a degenerate size — a capture must never be
  /// blocked on a measurement glitch.
  UnitRect _measureGuideBox() {
    final frameObject = _frameKey.currentContext?.findRenderObject();
    if (frameObject is! RenderBox || !frameObject.hasSize) {
      return UnitRect.full;
    }
    final previewRect = _measurePreview();
    if (previewRect == null) return UnitRect.full;

    final guideRect = frameObject.localToGlobal(Offset.zero) & frameObject.size;

    return UnitRect(
      left: (guideRect.left - previewRect.left) / previewRect.width,
      top: (guideRect.top - previewRect.top) / previewRect.height,
      right: (guideRect.right - previewRect.left) / previewRect.width,
      bottom: (guideRect.bottom - previewRect.top) / previewRect.height,
    ).clamped();
  }

  /// The live preview's real rendered rect in global coordinates, or `null`
  /// when it has not been laid out (or came out degenerate).
  ///
  /// The one place that rect is read: the guide-box measurement above and the
  /// detected-quad overlay (F16-T05) both need it, and two copies of this
  /// would be two things to keep in sync.
  Rect? _measurePreview() {
    final previewObject = _previewKey.currentContext?.findRenderObject();
    if (previewObject is! RenderBox || !previewObject.hasSize) return null;

    final rect = previewObject.localToGlobal(Offset.zero) & previewObject.size;
    if (rect.width <= 0 || rect.height <= 0) return null;
    return rect;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: captureBackdrop,
      body: DecoratedBox(
        // The design's radial lift behind the viewfinder.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF2B3138), captureBackdrop],
          ),
        ),
        child: BlocConsumer<CameraCaptureCubit, CameraCaptureState>(
          // A captured photo is a one-shot hand-off, not a screen: react to it
          // in the listener and leave the builder to the visible states.
          listenWhen: (_, s) => s is CameraCaptured,
          listener: (context, state) {
            if (state is CameraCaptured) widget.onCaptured(state.photo);
          },
          builder: (context, state) => SafeArea(
            child: switch (state) {
              CameraCaptureError() => _CameraError(
                onRetry: context.read<CameraCaptureCubit>().start,
                onClose: widget.onClose,
              ),
              _ => _Viewfinder(
                state: state,
                onClose: widget.onClose,
                onShutter: _capture,
                frameKey: _frameKey,
                previewKey: _previewKey,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// The live view with its framing guide and shutter.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.state,
    required this.onClose,
    required this.onShutter,
    required this.frameKey,
    required this.previewKey,
  });

  final CameraCaptureState state;
  final VoidCallback onClose;
  final VoidCallback onShutter;

  /// See `_CameraCaptureScreenState`'s fields of the same name — used to
  /// measure the guide box against the live preview's real rect at capture
  /// time (F15-T03).
  final GlobalKey frameKey;
  final GlobalKey previewKey;

  @override
  Widget build(BuildContext context) {
    final isReady = state is CameraReady || state is CameraCapturing;

    return Stack(
      children: [
        if (isReady)
          Positioned.fill(
            child: Center(
              child: KeyedSubtree(
                key: previewKey,
                child: context.read<CameraCaptureCubit>().preview.build(
                  context,
                ),
              ),
            ),
          )
        else
          const Positioned.fill(child: _Opening()),
        if (isReady)
          Positioned.fill(child: ViewfinderFrame(frameKey: frameKey)),
        Positioned(
          top: 8,
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _CloseButton(onTap: onClose),
          ),
        ),
        if (isReady)
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Hint(),
                const SizedBox(height: AppSpacing.lg),
                _Shutter(enabled: state is CameraReady, onTap: onShutter),
              ],
            ),
          ),
      ],
    );
  }
}

/// The dark loading state while the camera opens.
class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final onDark = AppColors.of(context).onBrand;

    return Semantics(
      liveRegion: true,
      label: s.cameraOpening,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: onDark.withValues(alpha: 0.85)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            s.cameraOpening,
            style: AppTypography.bodyMedium.copyWith(
              color: onDark.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rounded translucent close control, top-start.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return Semantics(
      button: true,
      label: s.cameraCloseLabel,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: _controlBox,
            height: _controlBox,
            child: Icon(
              Icons.close_rounded,
              color: AppColors.of(context).onBrand,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// The hint pill above the shutter, with its pulsing mint dot.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(_hintRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              s.cameraViewfinderHint,
              style: AppTypography.caption.copyWith(
                color: AppColors.of(context).onBrand,
                fontWeight: AppTypography.semiBold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mint dot that pulses beside the hint.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.of(context).mint,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The white shutter. Disabled mid-capture so it cannot fire twice.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return Semantics(
      button: true,
      enabled: enabled,
      label: s.cameraShutterLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: _shutterOuter,
          height: _shutterOuter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: enabled ? 1 : 0.6),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.25),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: _shutterInner,
              height: _shutterInner,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: captureBackdrop, width: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full-screen error state, with a retry and a way back.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final onDark = AppColors.of(context).onBrand;

    return Stack(
      children: [
        Positioned(
          top: 8,
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _CloseButton(onTap: onClose),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.no_photography_outlined,
                  color: onDark.withValues(alpha: 0.85),
                  size: 48,
                  semanticLabel: s.cameraCaptureErrorTitle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  s.cameraCaptureErrorTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMedium.copyWith(color: onDark),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.cameraCaptureErrorMessage,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: onDark.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.of(context).brandPrimary,
                    foregroundColor: onDark,
                    minimumSize: const Size.fromHeight(52),
                    textStyle: AppTypography.labelLarge,
                  ),
                  child: Text(s.actionRetry),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
