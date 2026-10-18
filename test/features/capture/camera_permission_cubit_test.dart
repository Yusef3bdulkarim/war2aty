import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_state.dart';

import '../../support/fakes.dart';

CameraPermissionCubit cubitFor(FakeCameraPermissionRepository repository) {
  return CameraPermissionCubit(
    getCameraPermission: GetCameraPermission(repository),
    requestCameraPermission: RequestCameraPermission(repository),
    openPermissionSettings: OpenPermissionSettings(repository),
  );
}

void main() {
  group('CameraPermissionCubit', () {
    test('starts out checking, before anything is read', () {
      final cubit = cubitFor(
        FakeCameraPermissionRepository(status: PermissionOutcome.denied),
      );
      addTearDown(cubit.close);

      expect(cubit.state, const CameraPermissionChecking());
    });

    test('lets an already-granted user straight through', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.granted,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state, const CameraPermissionGranted());
    });

    test('shows the explanation before the system prompt', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state, const CameraPermissionDenied());
      expect(repository.status, PermissionOutcome.denied);
    });

    test('granting at the prompt opens the capture flow', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
        afterRequest: PermissionOutcome.granted,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.allow();

      expect(cubit.state, const CameraPermissionGranted());
    });

    test('refusing at the prompt keeps the explanation up', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
        afterRequest: PermissionOutcome.denied,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.allow();

      expect(cubit.state, const CameraPermissionDenied());
    });

    test('a permanent denial switches the sheet to its blocked form', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
        afterRequest: PermissionOutcome.permanentlyDenied,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.allow();

      expect(cubit.state, const CameraPermissionBlocked());
    });

    test(
      'once blocked, allowing opens settings instead of prompting',
      () async {
        final repository = FakeCameraPermissionRepository(
          status: PermissionOutcome.permanentlyDenied,
        );
        final cubit = cubitFor(repository);
        addTearDown(cubit.close);

        await cubit.refresh();
        await cubit.allow();

        expect(repository.openSettingsCount, 1);
        // Still blocked: the answer only arrives when the app resumes.
        expect(cubit.state, const CameraPermissionBlocked());
      },
    );

    test('granting in settings is picked up on the next refresh', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.permanentlyDenied,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.allow();
      repository.status = PermissionOutcome.granted;
      await cubit.refresh();

      expect(cubit.state, const CameraPermissionGranted());
    });

    test('a platform failure leaves a usable "ask again" sheet', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
        fails: true,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(cubit.state, const CameraPermissionDenied());

      await cubit.allow();
      expect(cubit.state, const CameraPermissionDenied());
    });

    // The first-grant bug: the gate watches app resumes so a trip to Settings
    // is noticed, but the system prompt is a trip out of the foreground too.
    // Dismissing it resumed the app and fired a refresh at an OS that had not
    // finished committing the grant, and that stale read landed on top of the
    // answer — leaving the user looking at the sheet (or the viewfinder's
    // error) until they pressed the button a second time.
    test('the resume from its own prompt cannot undo the answer', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
        afterRequest: PermissionOutcome.granted,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(cubit.state, const CameraPermissionDenied());
      expect(repository.currentStatusCount, 1);

      // The prompt is on screen: the request has not answered yet.
      final prompt = Completer<void>();
      repository.requestGate = prompt;
      final allowing = cubit.allow();

      // Dismissing it takes the app through `resumed`, so the gate re-checks.
      await cubit.refresh();
      expect(
        repository.currentStatusCount,
        1,
        reason:
            'the platform must not be read while the prompt owns the answer',
      );
      expect(cubit.state, const CameraPermissionDenied());

      prompt.complete();
      await allowing;

      expect(cubit.state, const CameraPermissionGranted());
    });

    test('a second tap does not fire a second prompt', () async {
      final repository = FakeCameraPermissionRepository(
        status: PermissionOutcome.denied,
        afterRequest: PermissionOutcome.granted,
      );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);

      await cubit.refresh();

      final prompt = Completer<void>();
      repository.requestGate = prompt;
      final first = cubit.allow();
      final second = cubit.allow();

      prompt.complete();
      await Future.wait([first, second]);

      expect(
        repository.requestCount,
        1,
        reason: 'Android rejects a request made while one is already running',
      );
      expect(cubit.state, const CameraPermissionGranted());
    });

    test('does nothing once closed', () async {
      final cubit = cubitFor(
        FakeCameraPermissionRepository(status: PermissionOutcome.granted),
      );
      await cubit.close();

      await cubit.refresh();
      await cubit.allow();

      expect(cubit.state, const CameraPermissionChecking());
    });
  });
}
