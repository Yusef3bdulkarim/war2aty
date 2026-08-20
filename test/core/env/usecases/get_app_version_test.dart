import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/env/app_environment.dart';
import 'package:war2aty/core/env/usecases/get_app_version.dart';

// F11-T12: settings' «الإصدار» line.
void main() {
  test('reads the version off the environment', () {
    final useCase = GetAppVersion(
      AppEnvironment.dev(isAndroid: false, appVersion: '2.3.1'),
    );

    expect(useCase(), '2.3.1');
  });

  test('falls back to the platform-bundle default when unset', () {
    final useCase = GetAppVersion(AppEnvironment.dev(isAndroid: false));

    expect(useCase(), AppEnvironment.fallbackAppVersion);
  });
}
