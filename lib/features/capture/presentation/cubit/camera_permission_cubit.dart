import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../domain/usecases/get_camera_permission.dart';
import '../../domain/usecases/open_permission_settings.dart';
import '../../domain/usecases/request_camera_permission.dart';
import 'camera_permission_state.dart';

/// Owns the camera gate in front of the capture flow.
///
/// The order is deliberate: check silently, explain, *then* prompt. The system
/// dialog is a one-shot resource on Android and iOS — spending it before the
/// user understands why the app wants the camera is how a flow ends up
/// permanently denied.
final class CameraPermissionCubit extends Cubit<CameraPermissionState> {
  CameraPermissionCubit({
    required GetCameraPermission getCameraPermission,
    required RequestCameraPermission requestCameraPermission,
    required OpenPermissionSettings openPermissionSettings,
  }) : _getCameraPermission = getCameraPermission,
       _requestCameraPermission = requestCameraPermission,
       _openPermissionSettings = openPermissionSettings,
       super(const CameraPermissionChecking());

  final GetCameraPermission _getCameraPermission;
  final RequestCameraPermission _requestCameraPermission;
  final OpenPermissionSettings _openPermissionSettings;

  /// Reads the current state without prompting. Call on entering the flow,
  /// and again whenever the app is resumed — the user may have granted the
  /// camera in Settings while away.
  Future<void> refresh() async {
    if (isClosed) return;

    final result = await _getCameraPermission();
    if (isClosed) return;

    emit(result.fold(_stateFor, _deniedOn));
  }

  /// The sheet's primary action.
  ///
  /// Shows the system prompt while one can still be shown; once the OS has
  /// stopped prompting, the same button hands over to the settings app, since
  /// that is the only place the decision can still change.
  Future<void> allow() async {
    if (isClosed) return;

    if (state is CameraPermissionBlocked) {
      await _openPermissionSettings();
      // No emit: the answer arrives when the app resumes and [refresh] runs.
      return;
    }

    final result = await _requestCameraPermission();
    if (isClosed) return;

    emit(result.fold(_stateFor, _deniedOn));
  }

  CameraPermissionState _stateFor(PermissionOutcome outcome) =>
      switch (outcome) {
        PermissionOutcome.granted => const CameraPermissionGranted(),
        PermissionOutcome.denied => const CameraPermissionDenied(),
        PermissionOutcome.permanentlyDenied => const CameraPermissionBlocked(),
      };

  /// A platform failure is treated as "not granted, ask again" rather than a
  /// dead end: the user keeps a working button, and the gallery route out of
  /// the sheet is still there either way.
  CameraPermissionState _deniedOn(Object _) => const CameraPermissionDenied();
}
