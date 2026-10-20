import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/teal_top_bar.dart';
import '../../domain/entities/camera_flash_mode.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/focus_point.dart';
import '../capture_palette.dart';
import '../cubit/camera_capture_cubit.dart';
import '../cubit/camera_capture_state.dart';
import '../widgets/camera_capsule.dart';
import '../widgets/camera_status_line.dart';
import '../widgets/focusable_preview.dart';

// From the approved F24 design (`docs/design/F24-camera-mockups.html`, C2).
const double _feedGap = 8;
const double _dockGap = 14;
const double _dockBottom = 22;

/// The viewfinder (F24): the app's teal bar, the live feed full width and
/// Fit, and a dock below it with the status line and the glass capsule —
/// photos, shutter, flash. Nothing covers the paper but the focus brackets.
///
/// The screen owns the app-lifecycle wiring — the camera is released when the
/// app goes to the background and re-opened on return, so it is never held
/// while another app or the lock screen needs it.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    required this.onCaptured,
    required this.onClose,
    required this.onPickFromPhone,
    super.key,
  });

  /// Hands the finished photo to the next stage (crop / review, F03-T04+).
  final ValueChanged<CapturedPhoto> onCaptured;

  /// Leaves the capture flow.
  final VoidCallback onClose;

  /// Swaps the camera for the phone's photo picker (F24).
  final VoidCallback onPickFromPhone;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver, RouteAware {
  static const Duration _hintFor = Duration(seconds: 4);
  static const Duration _chipFor = Duration(seconds: 2);

  /// The focus hint shows once per camera visit (F24). This state lives as
  /// long as the camera route, so a retake ([didPopNext]), a retry or a trip
  /// to the background does not bring it back.
  bool _hintShown = false;
  bool _hintVisible = false;
  Timer? _hintTimer;

  /// The flash mode being spelled out after a tap, or `null`.
  CameraFlashMode? _flashChip;
  Timer? _chipTimer;

  /// Set when the camera was released because the app left the foreground, so
  /// that only a resume which actually follows one re-opens it.
  ///
  /// Without this the viewfinder re-opened the camera on *any* resume, and on
  /// a first grant it mounts in the middle of the permission prompt's own
  /// lifecycle transition: the tail of that transition arrived here as a
  /// release and a re-open while [initState]'s own `start()` was still opening
  /// the device. Three sessions overlapped, the last found the camera still
  /// held by the first, and the user was shown the error screen for a camera
  /// that was working perfectly.
  bool _releasedForBackground = false;

  /// Set while another route covers this one — the crop/preview screen, or the
  /// OCR screens a "retake" replaced it with.
  ///
  /// In-app navigation never changes the app's lifecycle state, so without
  /// this nothing noticed at all: the camera route stayed mounted underneath
  /// the pushed one with the device still open and streaming, for the whole
  /// rest of the flow — the crop, the OCR, the review, the result.
  bool _coveredByRoute = false;

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
    _hintTimer?.cancel();
    _chipTimer?.cancel();
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
        if (!_releasedForBackground) return;
        // Cleared either way, so a later backgrounding still releases; only
        // the re-open waits, for [didPopNext] to uncover the viewfinder.
        _releasedForBackground = false;
        if (_coveredByRoute) return;
        cubit.start();
      // Every transient interruption passes through `inactive`: the camera
      // permission prompt, the notification shade, control centre, a call
      // banner. None of them takes the camera away, and a real backgrounding
      // always follows with `paused`, so there is nothing to release here —
      // releasing it here is what made the first grant race itself.
      case AppLifecycleState.inactive:
        return;
      // Going down the platform reports `hidden` and then `paused`, so the
      // flag also keeps this to one release per backgrounding rather than a
      // redundant second teardown on the way.
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_releasedForBackground) return;
        _releasedForBackground = true;
        cubit.suspend();
    }
  }

  /// Fires when a route is pushed on top of this one — the crop/preview
  /// screen after a shot, and anything the user reaches from there.
  ///
  /// The camera goes with it. A pushed route does not pop this screen or
  /// change the app's lifecycle state, so nothing else here would notice:
  /// the device was left open and streaming behind the preview, the OCR, the
  /// review and the result, holding the hardware for the entire flow when the
  /// viewfinder was not even on screen.
  @override
  void didPushNext() {
    _coveredByRoute = true;
    context.read<CameraCaptureCubit>().suspend();
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
    _coveredByRoute = false;
    context.read<CameraCaptureCubit>().start();
  }

  void _showHint() {
    _hintShown = true;
    setState(() => _hintVisible = true);
    _hintTimer = Timer(_hintFor, _hideHint);
  }

  void _hideHint() {
    _hintTimer?.cancel();
    if (mounted && _hintVisible) setState(() => _hintVisible = false);
  }

  void _showFlashChip(CameraFlashMode mode) {
    _hideHint();
    _chipTimer?.cancel();
    setState(() => _flashChip = mode);
    _chipTimer = Timer(_chipFor, () {
      if (mounted) setState(() => _flashChip = null);
    });
  }

  void _focus(FocusPoint point) {
    _hideHint();
    context.read<CameraCaptureCubit>().focusAt(point);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
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
          child: Column(
            children: [
              TealTopBar(backTooltip: s.actionBack, onBack: widget.onClose),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: MultiBlocListener(
                    listeners: [
                      // A captured photo is a one-shot hand-off, not a screen.
                      BlocListener<CameraCaptureCubit, CameraCaptureState>(
                        listenWhen: (_, s) => s is CameraCaptured,
                        listener: (_, state) {
                          if (state is CameraCaptured) {
                            widget.onCaptured(state.photo);
                          }
                        },
                      ),
                      // A lens that cannot focus on a point gets no hint: the
                      // tap it suggests would do nothing.
                      BlocListener<CameraCaptureCubit, CameraCaptureState>(
                        listenWhen: (_, s) =>
                            s is CameraReady &&
                            s.capabilities.canFocus &&
                            !_hintShown,
                        listener: (_, _) => _showHint(),
                      ),
                      // Only a change while armed is the user's tap; the reset
                      // to off on every open is not announced.
                      BlocListener<CameraCaptureCubit, CameraCaptureState>(
                        listenWhen: (previous, current) =>
                            previous is CameraReady &&
                            current is CameraReady &&
                            previous.flashMode != current.flashMode,
                        listener: (_, state) {
                          if (state is CameraReady) {
                            _showFlashChip(state.flashMode);
                          }
                        },
                      ),
                    ],
                    child: BlocBuilder<CameraCaptureCubit, CameraCaptureState>(
                      builder: (context, state) => switch (state) {
                        CameraLive() => _Viewfinder(
                          state: state,
                          hintVisible: _hintVisible,
                          flashChip: _flashChip,
                          onFocus: _focus,
                          onPickFromPhone: widget.onPickFromPhone,
                        ),
                        CameraCaptureError() => _CameraError(
                          onRetry: context.read<CameraCaptureCubit>().start,
                          onPickFromPhone: widget.onPickFromPhone,
                        ),
                        CameraInitializing() ||
                        CameraCaptured() => const _Opening(),
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The feed, full width under the bar, and the dock pinned to the bottom.
///
/// The feed is Fit at the camera's own shape. Android gives a 16:9 picture,
/// which at full width runs under the dock; the owner chose that over a
/// narrower feed with side bands (F24, layout option b).
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.state,
    required this.hintVisible,
    required this.flashChip,
    required this.onFocus,
    required this.onPickFromPhone,
  });

  final CameraLive state;
  final bool hintVisible;
  final CameraFlashMode? flashChip;
  final ValueChanged<FocusPoint> onFocus;
  final VoidCallback onPickFromPhone;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCaptureCubit>();
    final armed = state is CameraReady;

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _feedGap),
          child: Align(
            alignment: Alignment.topCenter,
            child: FocusablePreview(
              preview: cubit.preview.build(context),
              enabled: armed && state.capabilities.canFocus,
              onFocus: onFocus,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: _dockBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CameraStatusLine(
                  hintVisible: hintVisible,
                  flashChip: flashChip,
                ),
                const SizedBox(height: _dockGap),
                CameraCapsule(
                  flashMode: state.flashMode,
                  hasFlash: state.capabilities.hasFlash,
                  shutterEnabled: armed,
                  onShutter: cubit.capture,
                  onFlash: cubit.cycleFlash,
                  onPickFromPhone: onPickFromPhone,
                ),
              ],
            ),
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

/// The camera could not open or a shot failed: retry, or take a photo from
/// the phone instead (F24). The teal bar above still leads back.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.onRetry, required this.onPickFromPhone});

  final VoidCallback onRetry;
  final VoidCallback onPickFromPhone;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = AppColors.of(context);
    final onDark = colors.onBrand;

    return Center(
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
                backgroundColor: colors.brandPrimary,
                foregroundColor: onDark,
                minimumSize: const Size.fromHeight(52),
                textStyle: AppTypography.labelLarge,
              ),
              child: Text(s.actionRetry),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onPickFromPhone,
              style: OutlinedButton.styleFrom(
                foregroundColor: onDark,
                side: BorderSide(
                  color: onDark.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                minimumSize: const Size.fromHeight(52),
                textStyle: AppTypography.labelLarge,
              ),
              child: Text(s.cameraPickFromPhone),
            ),
          ],
        ),
      ),
    );
  }
}
