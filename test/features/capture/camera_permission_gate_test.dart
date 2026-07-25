import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/screens/camera_permission_gate.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _strings = ArStrings();

/// Pumps the gate over a stand-in for the capture screen, recording the two
/// ways out so the test can assert which one the user took.
Future<_Exits> _pumpGate(
  WidgetTester tester,
  FakeCameraPermissionRepository repository, {
  TextScaler? textScaler,
}) async {
  final exits = _Exits();
  final cubit = CameraPermissionCubit(
    getCameraPermission: GetCameraPermission(repository),
    requestCameraPermission: RequestCameraPermission(repository),
    openPermissionSettings: OpenPermissionSettings(repository),
  );
  addTearDown(cubit.close);

  await pumpApp(
    tester,
    BlocProvider<CameraPermissionCubit>.value(
      value: cubit,
      child: CameraPermissionGate(
        granted: (_) => const Text('viewfinder'),
        onPickInstead: () => exits.pickedInstead = true,
        onDismiss: () => exits.dismissed = true,
      ),
    ),
    textScaler: textScaler,
  );
  return exits;
}

void main() {
  group('CameraPermissionGate', () {
    testWidgets('a granted camera never sees the sheet', (tester) async {
      await _pumpGate(
        tester,
        FakeCameraPermissionRepository(status: PermissionOutcome.granted),
      );

      expect(find.text('viewfinder'), findsOneWidget);
      expect(find.text(_strings.cameraPermissionTitle), findsNothing);
    });

    testWidgets('explains itself before prompting', (tester) async {
      await _pumpGate(
        tester,
        FakeCameraPermissionRepository(status: PermissionOutcome.denied),
      );

      expect(find.text(_strings.cameraPermissionTitle), findsOneWidget);
      expect(find.text(_strings.cameraPermissionMessage), findsOneWidget);
      expect(find.text(_strings.cameraPermissionAllow), findsOneWidget);
    });

    testWidgets('offers the gallery as a way forward', (tester) async {
      final exits = await _pumpGate(
        tester,
        FakeCameraPermissionRepository(status: PermissionOutcome.denied),
      );

      await tester.tap(find.text(_strings.cameraPermissionPickInstead));
      await tester.pumpAndSettle();

      expect(exits.pickedInstead, isTrue);
    });

    testWidgets('backs out of the flow', (tester) async {
      final exits = await _pumpGate(
        tester,
        FakeCameraPermissionRepository(status: PermissionOutcome.denied),
      );

      await tester.tap(find.text(_strings.actionBack));
      await tester.pumpAndSettle();

      expect(exits.dismissed, isTrue);
    });

    testWidgets('allowing at the prompt reveals the capture screen', (
      tester,
    ) async {
      await _pumpGate(
        tester,
        FakeCameraPermissionRepository(
          status: PermissionOutcome.denied,
          afterRequest: PermissionOutcome.granted,
        ),
      );

      await tester.tap(find.text(_strings.cameraPermissionAllow));
      await tester.pumpAndSettle();

      expect(find.text('viewfinder'), findsOneWidget);
    });

    testWidgets('a blocked camera points at the settings app', (tester) async {
      await _pumpGate(
        tester,
        FakeCameraPermissionRepository(
          status: PermissionOutcome.permanentlyDenied,
        ),
      );

      expect(find.text(_strings.cameraPermissionOpenSettings), findsOneWidget);
      expect(
        find.text(_strings.cameraPermissionBlockedMessage),
        findsOneWidget,
      );
      expect(find.text(_strings.cameraPermissionAllow), findsNothing);
    });

    testWidgets('lays out right-to-left', (tester) async {
      await _pumpGate(
        tester,
        FakeCameraPermissionRepository(status: PermissionOutcome.denied),
      );

      expect(
        Directionality.of(
          tester.element(find.text(_strings.cameraPermissionTitle)),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      await _pumpGate(
        tester,
        FakeCameraPermissionRepository(status: PermissionOutcome.denied),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_strings.cameraPermissionAllow), findsOneWidget);
    });
  });
}

/// Which way out of the gate the user took.
final class _Exits {
  bool pickedInstead = false;
  bool dismissed = false;
}
