import '../app_environment.dart';

/// The app's version string, as read from the platform bundle at launch.
///
/// A thin usecase around [AppEnvironment] rather than injecting the
/// environment itself into a Cubit — Cubits depend on use cases only. Backs
/// the settings screen's «الإصدار» line (F11-T12).
final class GetAppVersion {
  const GetAppVersion(this._environment);

  final AppEnvironment _environment;

  String call() => _environment.appVersion;
}
