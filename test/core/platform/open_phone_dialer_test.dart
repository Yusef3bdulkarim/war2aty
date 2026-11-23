import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/platform/external_link_service.dart';
import 'package:war2aty/core/platform/usecases/open_phone_dialer.dart';
import 'package:war2aty/core/result/result.dart';

final class _FakeExternalLinkService implements ExternalLinkService {
  _FakeExternalLinkService({this.result = true, this.throws = false});

  bool result;
  bool throws;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri destination) async {
    opened.add(destination);
    if (throws) throw Exception('no activity found');
    return result;
  }
}

void main() {
  group('OpenPhoneDialer', () {
    test('hands the platform a tel: uri built from the digits', () async {
      final service = _FakeExternalLinkService();
      final dialer = OpenPhoneDialer(service);

      await dialer('0453312244');

      expect(service.opened, [Uri(scheme: 'tel', path: '0453312244')]);
    });

    test('"nothing could open it" is a value, not a failure', () async {
      final dialer = OpenPhoneDialer(_FakeExternalLinkService(result: false));

      final result = await dialer('0453312244');

      expect(result, const Ok<bool, AppFailure>(false));
    });

    test(
      'a thrown platform error becomes a failure, never an exception',
      () async {
        final dialer = OpenPhoneDialer(_FakeExternalLinkService(throws: true));

        final result = await dialer('0453312244');

        expect(result, const Err<bool, AppFailure>(ExternalLinkFailure()));
      },
    );
  });

  group('the app can actually dial on Android', () {
    test('a tel VIEW intent is declared', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

      expect(
        manifest,
        contains(
          '<intent> <action android:name="android.intent.action.VIEW"/> '
          '<data android:scheme="tel"/> </intent>',
        ),
      );
    });
  });
}
