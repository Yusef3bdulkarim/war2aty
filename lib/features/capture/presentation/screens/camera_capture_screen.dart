import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/captured_photo.dart';
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
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<CameraCaptureCubit>().start();
  }

  @override
  void dispose() {
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
                onShutter: context.read<CameraCaptureCubit>().capture,
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
  });

  final CameraCaptureState state;
  final VoidCallback onClose;
  final VoidCallback onShutter;

  @override
  Widget build(BuildContext context) {
    final isReady = state is CameraReady || state is CameraCapturing;

    return Stack(
      children: [
        if (isReady)
          Positioned.fill(
            child: Center(
              child: context.read<CameraCaptureCubit>().preview.build(context),
            ),
          )
        else
          const Positioned.fill(child: _Opening()),
        if (isReady) const Positioned.fill(child: ViewfinderFrame()),
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
    final onDark = AppColors.light.onBrand;

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
              color: AppColors.light.onBrand,
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
                color: AppColors.light.onBrand,
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
          color: AppColors.light.mint,
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
    final onDark = AppColors.light.onBrand;

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
                    backgroundColor: AppColors.light.brandPrimary,
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
