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
}
