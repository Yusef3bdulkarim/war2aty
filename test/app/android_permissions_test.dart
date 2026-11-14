import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F27-T16: the app declares only the permissions it uses, and keeps the
/// plugins' extras out of the merged manifest.
///
/// The hand-written manifest was always clean — five permissions, all needed.
/// The *merged* prod-release manifest was not: `camera_android_camerax`
/// contributes `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE`, and the manifest
/// merger then derives `READ_EXTERNAL_STORAGE` from the WRITE — without the
/// `maxSdkVersion="28"` the WRITE carries, so it stayed live on API 29-32 where
/// it grants read access to all shared media.
///
/// Neither was ever requested at runtime, which is why this was a Low and not a
/// defect in behaviour. It still mattered twice over: both appear in the Play
/// listing and in Android's app-info screen, which is the wrong thing for an app
/// whose promise is "we do not keep your paper" to be asking for; and the
/// declaration is the gate, so while it stood a later plugin upgrade could take
/// the microphone or the whole media library with no manifest edit and so no
/// review.
///
/// A regression guard, not a unit test: these are `tools:node="remove"`
/// directives in XML that no Dart code reads, so nothing else in the suite
/// would notice them being dropped by a merge or a template update. Verified
/// against the real merged manifest at the time of the fix with
/// `aapt2 dump xmltree` / by reading
/// `build/app/intermediates/merged_manifests/prodRelease/...`.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// Permissions the app genuinely uses. Each is justified by a comment in the
  /// manifest itself.
  const declared = [
    'android.permission.CAMERA',
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.WAKE_LOCK',
  ];

  /// Permissions a plugin contributes that this app must not ship. WRITE is
  /// removed as well as READ, because leaving the WRITE lets the merger
  /// re-derive the READ.
  const removed = [
    'android.permission.RECORD_AUDIO',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_EXTERNAL_STORAGE',
  ];

  group('Android permissions (F27-T16)', () {
    test('the tools namespace is declared, or tools:node does nothing', () {
      expect(
        manifest,
        contains('xmlns:tools="http://schemas.android.com/tools"'),
        reason:
            'without the namespace the merger ignores tools:node="remove" and '
            'the permissions come back silently',
      );
    });

    test('every permission the app uses is still declared', () {
      for (final permission in declared) {
        expect(
          manifest,
          contains('android:name="$permission"'),
          reason: '$permission is used by the app and must stay declared',
        );
      }
    });

    test('the plugins\' extra permissions are removed from the merge', () {
      for (final permission in removed) {
        // The element must exist AND carry the remove directive: a bare
        // `<uses-permission>` for one of these would *add* it instead.
        final pattern = RegExp(
          '<uses-permission\\s+android:name="${RegExp.escape(permission)}"'
          '\\s+tools:node="remove"\\s*/>',
          multiLine: true,
        );
        expect(
          pattern.hasMatch(manifest),
          isTrue,
          reason:
              '$permission must be removed with tools:node="remove"; the app '
              'never requests it and it should not reach the Play listing',
        );
      }
    });

    test('the voice spine added no permission (F37-T21)', () {
      // F37 plays audio and encodes it; it never records. `AudioTrack`,
      // `MediaCodec` and `just_audio` all need nothing declared, so the voice
      // spine must leave this file exactly as it was — and `RECORD_AUDIO` in
      // particular must stay *removed*, which the list above already asserts.
      //
      // This is here as a named guard rather than trusted to the list, because
      // "the app speaks and records" is the obvious wrong assumption for
      // someone adding a voice feature later, and the microphone is the one
      // permission this app's privacy promise cannot survive asking for.
      expect(
        manifest,
        isNot(contains('android.permission.MODIFY_AUDIO_SETTINGS')),
        reason:
            'audio focus for playback needs no permission; declaring this '
            'would appear in the Play listing for nothing',
      );
      expect(
        manifest.contains('android.permission.RECORD_AUDIO'),
        isTrue,
        reason: 'the removal directive itself must still be present',
      );
    });

    test('no permission is declared beyond the two lists', () {
      // Catches a new permission arriving without anyone deciding it should.
      final found = RegExp(
        r'android:name="(android\.permission\.[A-Z_]+)"',
      ).allMatches(manifest).map((match) => match.group(1)!).toSet();

      expect(
        found.difference({...declared, ...removed}),
        isEmpty,
        reason:
            'a permission appeared in the manifest that this guard does not '
            'know about — justify it and add it to `declared`, or remove it',
      );
    });
  });

  /// F37-T21: the voice channel's two ends agree, and something plugs it in.
  ///
  /// A method channel is a **string on each side**. Nothing checks that the two
  /// match: no compiler sees both languages, and a mismatch does not throw —
  /// the Dart call simply goes to a channel with no handler, so the paper is
  /// read in silence and the only symptom is a voice that never speaks. The
  /// same is true of forgetting to construct the plugin in `MainActivity`:
  /// every name can be right and still nothing listens.
  ///
  /// So this reads both files and compares the literals. It belongs beside the
  /// permission guard for the same reason that one exists — these are
  /// cross-language facts that no unit test reaches and that only a device
  /// would otherwise reveal.
  group('the voice audio channel (F37-T21)', () {
    final plugin = File(
      'android/app/src/main/kotlin/com/war2aty/app/voice/VoiceAudioPlugin.kt',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/war2aty/app/MainActivity.kt',
    ).readAsStringSync();
    final dartSide = File(
      'lib/features/voice/data/services/method_channel_live_audio_output.dart',
    ).readAsStringSync();

    /// Both ends name the same two channels: one for control, one for PCM.
    const channels = [
      'com.war2aty.app/voice_audio',
      'com.war2aty.app/voice_audio_pcm',
    ];

    test('MainActivity constructs the plugin', () {
      expect(
        mainActivity,
        contains('VoiceAudioPlugin(flutterEngine, this)'),
        reason:
            'without this line the channels have no handler and every read is '
            'silent, with no error anywhere',
      );
    });

    for (final channel in channels) {
      test('"$channel" is named identically on both sides', () {
        expect(
          plugin,
          contains('"$channel"'),
          reason: 'the Kotlin side no longer serves this channel name',
        );
        expect(
          dartSide,
          contains("'$channel'"),
          reason: 'the Dart side no longer calls this channel name',
        );
      });
    }

    test('neither side invents a third voice channel', () {
      // A new channel on one side only is the same silent failure as a
      // renamed one. Catching it needs the *set*, not each name.
      final found = {
        ...RegExp(
          r'"(com\.war2aty\.app/voice[a-z_]*)"',
        ).allMatches(plugin).map((m) => m.group(1)!),
        ...RegExp(
          r"'(com\.war2aty\.app/voice[a-z_]*)'",
        ).allMatches(dartSide).map((m) => m.group(1)!),
      };

      expect(
        found,
        unorderedEquals(channels),
        reason:
            'a voice channel appeared on one side that this guard does not '
            'know about — add it here and to the other side',
      );
    });
  });
}
