import 'package:permission_handler/permission_handler.dart' as ph;

import 'permission_service.dart';

/// [PermissionService] backed by the `permission_handler` plugin.
///
/// The only file in the app allowed to import that plugin — everything above
/// it speaks [AppPermission] / [PermissionOutcome].
final class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  @override
  Future<PermissionOutcome> check(AppPermission permission) async =>
      _map(await _plugin(permission).status);

  @override
  Future<PermissionOutcome> request(AppPermission permission) async =>
      _map(await _plugin(permission).request());

  @override
  Future<bool> openSettings() => ph.openAppSettings();

  ph.Permission _plugin(AppPermission permission) => switch (permission) {
    AppPermission.camera => ph.Permission.camera,
  };

  /// Folds the plugin's status into the three cases the app acts on.
  ///
  /// `limited` and `provisional` mean the user said yes with a narrower scope
  /// — still a yes. `restricted` (parental controls, MDM) can only be changed
  /// outside the app, so it behaves exactly like a permanent denial.
  PermissionOutcome _map(ph.PermissionStatus status) => switch (status) {
    ph.PermissionStatus.granted ||
    ph.PermissionStatus.limited ||
    ph.PermissionStatus.provisional => PermissionOutcome.granted,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => PermissionOutcome.permanentlyDenied,
    ph.PermissionStatus.denied => PermissionOutcome.denied,
  };
}
