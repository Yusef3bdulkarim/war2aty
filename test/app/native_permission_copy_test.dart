import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';

/// The privacy contract of CLAUDE.md §7 (F18-T02 for the text, F20-T24 for the
/// image) applies to **every** string a user can read — and the iOS permission
/// alerts are the first privacy copy most users ever see, shown before the
/// onboarding screen `app_strings_test` already guards.
///
/// F27-T10 / B1: both usage descriptions used to end with «ومحدش بيشوف
/// صورتها», exactly the claim F20-T24 retired, and no test covered them
/// because they live in `Info.plist` rather than in `AppStrings`. This file is
/// that cover: it reads the native config straight off disk, so the plist and
/// the manifest are held to the same rules as the Dart copy.
void main() {
  // §7, unchanged since F13-T18: no user-facing string names a provider.
  const providers = ['Azure', 'Google', 'Gemini', 'Mistral', 'Groq', 'OpenAI'];

  group('iOS permission prompts (Info.plist)', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    /// Every `…UsageDescription` key with its string, so a permission added
    /// later is covered by these checks without anyone remembering to.
    final descriptions = {
      for (final m in RegExp(
        r'<key>(\w*UsageDescription)</key>\s*<string>([^<]*)</string>',
      ).allMatches(plist))
        m.group(1)!: m.group(2)!,
    };

    test('the camera and photo-library prompts exist and are non-empty', () {
      expect(descriptions.keys, contains('NSCameraUsageDescription'));
      expect(descriptions.keys, contains('NSPhotoLibraryUsageDescription'));
      for (final MapEntry(key: key, value: copy) in descriptions.entries) {
        expect(copy.trim(), isNotEmpty, reason: '$key is empty');
      }
    });

    test('no prompt claims the photo goes unseen (F20-T24)', () {
      for (final MapEntry(key: key, value: copy) in descriptions.entries) {
        expect(
          copy,
          isNot(contains('محدش بيشوف')),
          reason: '$key: the online reader may review the photo',
        );
        expect(
          copy.toLowerCase(),
          isNot(contains('nobody sees')),
          reason: '$key: the online reader may review the photo',
        );
      }
    });

    test('no prompt claims the photo never leaves the phone', () {
      for (final MapEntry(key: key, value: copy) in descriptions.entries) {
        expect(
          copy,
          isNot(contains('متتحفظش خالص')),
          reason: '$key: an unscoped "never saved" is false (§7)',
        );
        expect(
          copy.toLowerCase(),
          isNot(contains('never leaves')),
          reason: '$key: online, the photo is sent out for reading',
        );
      }
    });

    test('a "we do not save it" promise is scoped to us (§7)', () {
      // §7 allows «مابنحفظش» only when the text says who: us, or the phone.
      // Unscoped, it reads as a promise nobody can keep for the outside
      // reader.
      for (final MapEntry(key: key, value: copy) in descriptions.entries) {
        if (!copy.contains('مابنحفظش')) continue;
        expect(
          copy,
          contains('إحنا مابنحفظش'),
          reason: '$key: say who does not save the photo',
        );
      }
    });

    test('the photo prompts say what really happens to the photo', () {
      // The same two halves `privacyPointExtractText` must state: online it
      // is sent out, may be kept for a while and reviewed by staff; offline
      // it is read only on the phone.
      for (final key in const [
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
      ]) {
        final copy = descriptions[key]!;
        expect(copy, contains('بنبعت صورة الورقة'), reason: key);
        expect(copy, contains('تحتفظ بيها فترة'), reason: key);
        expect(copy, contains('يراجعها موظفين'), reason: key);
        expect(copy, contains('إحنا مابنحفظش الصورة'), reason: key);
        expect(copy, contains('على موبايلك بس'), reason: key);
      }
    });

    test('the wording stays in step with the onboarding copy', () {
      // One source of truth for the promise: if `privacyPointExtractText` is
      // ever reworded, these clauses have to move with it.
      const ar = ArStrings();
      for (final clause in const [
        'بنبعت صورة الورقة',
        'يراجعها موظفين',
        'على موبايلك بس',
      ]) {
        expect(
          ar.privacyPointExtractText,
          contains(clause),
          reason: 'the plist mirrors a clause the app no longer uses',
        );
      }
    });

    test('no prompt names a provider', () {
      for (final MapEntry(key: key, value: copy) in descriptions.entries) {
        for (final name in providers) {
          expect(
            copy.toLowerCase(),
            isNot(contains(name.toLowerCase())),
            reason: '$name must never appear in $key',
          );
        }
      }
    });
  });

  group('Android-visible copy', () {
    test('the launcher labels are set and name no provider', () {
      // `android:label="${appName}"` resolves to these, the only Android copy
      // the app ships itself — the runtime permission prompts are Android's
      // own text, and the in-app rationale lives in `AppStrings`.
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final labels = RegExp(
        r'manifestPlaceholders\["appName"\]\s*=\s*"([^"]*)"',
      ).allMatches(gradle).map((m) => m.group(1)!).toList();

      expect(labels.length, 2, reason: 'one appName per flavor (dev, prod)');
      for (final label in labels) {
        expect(label.trim(), isNotEmpty);
        for (final name in providers) {
          expect(label.toLowerCase(), isNot(contains(name.toLowerCase())));
        }
      }
    });

    test('no manifest comment claims the image stays on the device', () {
      // F27-M3: the comment above CAMERA said "the image never leaves the
      // device", untrue since F20. Users never read it, but the next reader
      // of this file does, and the stale claim is how false copy comes back.
      for (final path in const [
        'android/app/src/main/AndroidManifest.xml',
        'android/app/src/debug/AndroidManifest.xml',
        'android/app/src/profile/AndroidManifest.xml',
      ]) {
        final manifest = File(path).readAsStringSync().toLowerCase();
        expect(
          manifest,
          isNot(contains('never leaves the device')),
          reason: '$path: online, the photo is sent out for reading',
        );
        expect(manifest, isNot(contains('محدش بيشوف')), reason: path);
      }
    });
  });
}
