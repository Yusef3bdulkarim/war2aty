import 'package:flutter/services.dart';

import 'system_tts_settings.dart';

/// [SystemTtsSettings] over a method channel the app's own Android host
/// answers (F30-T07).
///
/// The only file that talks to that channel. `MainActivity` fires
/// `ACTION_TTS_SETTINGS`; there is no iOS side, because iOS has no
/// text-to-speech settings screen to send anyone to — the channel simply has
/// no handler there, which arrives here as a [MissingPluginException] and is
/// reported as "nothing to open".
final class MethodChannelSystemTtsSettings implements SystemTtsSettings {
  const MethodChannelSystemTtsSettings();

  /// Named for the app rather than for a plugin, so it cannot collide with
  /// one. Must match the string in `MainActivity`.
  static const MethodChannel _channel = MethodChannel(
    'com.war2aty.app/system_settings',
  );

  @override
  Future<bool> isAvailable() => _ask('canOpenTtsSettings');

  @override
  Future<bool> open() => _ask('openTtsSettings');

  /// Both calls answer a bool and fail the same way, so they ask the same
  /// way: anything the host cannot do is "nothing to open" rather than a
  /// crash — see [SystemTtsSettings.open].
  Future<bool> _ask(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      // No host handler: iOS, or a platform the channel was never wired on.
      return false;
    } on PlatformException {
      return false;
    }
  }
}
