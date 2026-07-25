import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../capture_palette.dart';
import '../cubit/camera_permission_cubit.dart';
import '../cubit/camera_permission_state.dart';
import '../widgets/camera_permission_sheet.dart';

/// Stands between the user and the camera.
///
/// Granted goes straight through to [granted] — the sheet is only ever seen by
/// someone who has not said yes yet.
///
/// The design draws this sheet over the screen the user came from. Here it sits
/// over the viewfinder's own near-black backdrop instead: capture is a pushed,
/// full-screen task (it deliberately hides the nav bar), so the user has
/// already left Home by the time the question is asked.
class CameraPermissionGate extends StatefulWidget {
  const CameraPermissionGate({
    required this.granted,
    required this.onPickInstead,
    required this.onDismiss,
    super.key,
  });

  /// The capture flow itself, built once the camera is available.
  final WidgetBuilder granted;

  /// Leaves for the gallery route — the way to get a paper analysed without
  /// ever granting the camera.
  final VoidCallback onPickInstead;

  /// Backs out of the capture flow entirely.
  final VoidCallback onDismiss;

  @override
  State<CameraPermissionGate> createState() => _CameraPermissionGateState();
}

class _CameraPermissionGateState extends State<CameraPermissionGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The settings app is a round trip out of the process: the user may come
    // back having granted the camera, and only a re-check on resume notices.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() => context.read<CameraPermissionCubit>().refresh();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraPermissionCubit, CameraPermissionState>(
      builder: (context, state) => switch (state) {
        // Bare backdrop while the OS is being asked. It lasts a frame or two,
        // and it is the same surface the viewfinder lands on — so a granted
        // camera shows no flash of anything else on the way in.
        CameraPermissionChecking() => const ColoredBox(
          color: captureBackdrop,
          child: SizedBox.expand(),
        ),
        CameraPermissionGranted() => widget.granted(context),
        CameraPermissionDenied() ||
        CameraPermissionBlocked() => CameraPermissionSheet(
          isBlocked: state is CameraPermissionBlocked,
          onAllow: context.read<CameraPermissionCubit>().allow,
          onPickInstead: widget.onPickInstead,
          onDismiss: widget.onDismiss,
        ),
      },
    );
  }
}
