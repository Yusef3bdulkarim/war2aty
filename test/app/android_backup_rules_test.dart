import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F27-T11 / H2 / Q20: Android backup and transfer are off, and must stay off.
///
/// The manifest never set `allowBackup`, so Android's default (on) applied and
/// the SQLite archive — the extracted text of every analysed paper, with its
/// reminders — was eligible for the user's Google Drive, which nothing in the
/// privacy screen prepares them for. Worse, images are encrypted under a
/// Keystore key that cannot be backed up, so a restore returned ciphertext
/// with no key.
///
/// This file is a regression guard, not a unit test: the settings live in XML
/// that no Dart code reads, so nothing else in the suite would notice them
/// being dropped — by a merge, a Flutter template update, or someone copying
/// a fresh `AndroidManifest.xml` over this one.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// Each section of `data_extraction_rules.xml` INCLUDES everything it does
  /// not exclude, so a domain missing from the list is a leak rather than a
  /// no-op. All nine must appear in both sections.
  const domains = [
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ];

  group('Android backup is off (F27-T11)', () {
    test('the manifest sets allowBackup="false"', () {
      expect(
        manifest,
        contains('android:allowBackup="false"'),
        reason: 'omitting the attribute re-enables backup — the default is on',
      );
      expect(
        manifest,
        isNot(contains('android:allowBackup="true"')),
        reason: 'Q20: backup is off completely',
      );
    });

    test('the manifest points at the extraction rules', () {
      // Required on top of the attribute: for apps targeting API 31+ (this
      // app targets 36), `allowBackup="false"` stops cloud backup but, on
      // some manufacturers' devices, leaves device-to-device transfer on.
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
        reason: 'without this, D2D transfer can still copy the database',
      );
    });

    test('no full-backup rules contradict it', () {
      // `fullBackupContent` would only matter on API <= 30, where
      // `allowBackup="false"` already settles it — but a resource here would
      // mean someone re-opened the question in half.
      expect(manifest, isNot(contains('android:fullBackupContent')));
      expect(manifest, isNot(contains('android:backupAgent')));
    });
  });

  group('data_extraction_rules.xml excludes everything', () {
    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    /// The body of one section, so each is checked on its own contents
    /// rather than on the file as a whole.
    String section(String name) {
      final match = RegExp(
        '<$name[^>]*>(.*?)</$name>',
        dotAll: true,
      ).firstMatch(rules);
      expect(match, isNotNull, reason: 'the <$name> section is missing');
      return match!.group(1)!;
    }

    test('cloud backup (Google Drive) excludes every domain', () {
      final body = section('cloud-backup');
      for (final domain in domains) {
        expect(
          body,
          contains('<exclude domain="$domain" />'),
          reason: '$domain would be backed up to Drive',
        );
      }
    });

    test('device-to-device transfer excludes every domain', () {
      final body = section('device-transfer');
      for (final domain in domains) {
        expect(
          body,
          contains('<exclude domain="$domain" />'),
          reason: '$domain would be copied to the new phone',
        );
      }
    });

    test('no section includes anything', () {
      // An `<include>` anywhere means data was deliberately let back out;
      // that is a decision for the owner (Q20), not a code change.
      expect(
        rules.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ''),
        isNot(contains('<include')),
      );
    });
  });
}
