import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_play_compliance.dart';

/// F27-T19 · Play's artifact requirements, and the reader that checks them.
///
/// Two different kinds of test live here, for two different reasons.
///
/// **The target SDK and the permission allowlist** are guards. Play requires
/// API 36 of a new app since 2026-08-31, and `android/app/build.gradle.kts`
/// takes `targetSdk` from the Flutter SDK rather than pinning a number — which
/// is the right call (a pinned number goes stale while claiming to be a
/// decision) but means the value this project actually ships is decided
/// *outside the repo*, by whichever Flutter version is installed. So the test
/// reads it out of the SDK and fails if it ever drops below what Play wants.
///
/// **The ELF, ZIP and BundleConfig readers** are tested because
/// `tool/check_play_compliance.dart` is the only thing standing between a
/// plugin upgrade and a rejected release, and a mis-written binary reader
/// fails in the worst possible direction: it reports compliance it did not
/// verify. Each reader is therefore exercised against both a hand-built input
/// with a known answer and, for `BundleConfig.pb`, the exact bytes AGP 8.11.1
/// wrote into the real bundle.
///
/// What is NOT here: the checks against a real artifact. They need a signed
/// release build, which takes minutes and does not exist in CI, so they are a
/// release-time step (`docs/BUILD.md`) rather than a test. The run of
/// 2026-10-08 is recorded in `docs/features/F27-T19-play-compliance.md`.
void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  group('target SDK clears what Play requires', () {
    test('build.gradle.kts takes it from the Flutter SDK, not a literal', () {
      expect(
        gradle,
        contains('targetSdk = flutter.targetSdkVersion'),
        reason:
            'a pinned number here goes stale while looking like a decision '
            '(F27-T13); the SDK is the single source',
      );
    });

    test('the Flutter SDK this project builds with targets at least API '
        '$kPlayRequiredTargetSdk', () {
      final extension = File(
        '${_flutterRoot()}/packages/flutter_tools/gradle/src/main/kotlin/'
        'FlutterExtension.kt',
      );
      expect(
        extension.existsSync(),
        isTrue,
        reason:
            'cannot read ${extension.path} — the Flutter SDK layout has '
            'changed, and with it the way targetSdk is resolved. Find the new '
            'home of targetSdkVersion and fix this test rather than deleting '
            'it: it is the only check that the shipped target API still '
            'clears Play.',
      );

      final declared = RegExp(
        r'val\s+targetSdkVersion\s*:\s*Int\s*=\s*(\d+)',
      ).firstMatch(extension.readAsStringSync())?.group(1);
      expect(
        int.tryParse(declared ?? ''),
        isNotNull,
        reason: 'targetSdkVersion not found in ${extension.path}',
      );
      expect(
        int.parse(declared!),
        greaterThanOrEqualTo(kPlayRequiredTargetSdk),
        reason:
            'this Flutter SDK targets API $declared, and Play requires at '
            'least $kPlayRequiredTargetSdk of a new app or an update. Either '
            'upgrade Flutter or set targetSdk explicitly — the build is not '
            'publishable as it stands.',
      );
    });
  });

  group('the permission allowlist cannot drift from the manifest', () {
    // The tool's allowlist is checked against the *merged* manifest inside a
    // built artifact; `android_permissions_test` checks the source manifest.
    // Nothing connected the two lists, so a permission could be added to the
    // manifest with a justification and still be rejected by the tool at
    // release time, hours after the decision was made.
    test('every permission the manifest declares is in the allowlist', () {
      final declared = RegExp(r'android:name="(android\.permission\.[A-Z_]+)"')
          .allMatches(manifest)
          .map((match) => match.group(1)!)
          .where((permission) => !_removedByTheManifest(manifest, permission))
          .toSet();

      expect(
        declared,
        isNotEmpty,
        reason: 'the manifest regex matched nothing',
      );
      expect(
        declared.difference(kAllowedPermissions.keys.toSet()),
        isEmpty,
        reason:
            'the manifest declares a permission that '
            'tool/check_play_compliance.dart would reject at release time; '
            'add it to kAllowedPermissions with its justification',
      );
    });

    test('the permissions removed from the merge are not allowlisted', () {
      // If one of these ever came back through a plugin, the tool has to fail.
      for (final permission in const [
        'android.permission.RECORD_AUDIO',
        'android.permission.WRITE_EXTERNAL_STORAGE',
        'android.permission.READ_EXTERNAL_STORAGE',
      ]) {
        expect(
          kAllowedPermissions.containsKey(permission),
          isFalse,
          reason:
              '$permission is removed from the merged manifest on purpose '
              '(F27-T16); allowlisting it would let it back in silently',
        );
      }
    });

    test('every allowlisted permission carries a justification', () {
      for (final entry in kAllowedPermissions.entries) {
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason: '${entry.key} is allowed without saying why',
        );
      }
    });
  });

  group('which ABI a library belongs to', () {
    test('is read from the entry path, in both artifact layouts', () {
      expect(abiOf('lib/arm64-v8a/libtesseract.so'), 'arm64-v8a');
      expect(abiOf('base/lib/x86_64/libtesseract.so'), 'x86_64');
      expect(abiOf('base/lib/armeabi-v7a/libtesseract.so'), 'armeabi-v7a');
    });

    test('a library somewhere else is in neither ABI set', () {
      // This is what the tool's "cannot tell which ABI this is" failure
      // exists for. The exemption from the 16 KB requirement belongs to
      // 32-bit ABIs only, so an unplaceable `.so` must be reported rather
      // than fall through the `!required64` branch and be waved past.
      final stray = abiOf('base/root/lib/libsomething.so');
      expect(kAbis64Bit.contains(stray), isFalse);
      expect(kAbis32Bit.contains(stray), isFalse);
    });

    test(
      'the two ABI sets cover every ABI Android has, and do not overlap',
      () {
        expect(kAbis64Bit.intersection(kAbis32Bit), isEmpty);
        expect(
          {...kAbis64Bit, ...kAbis32Bit},
          {'arm64-v8a', 'x86_64', 'armeabi-v7a', 'x86'},
        );
      },
    );
  });

  group('the ELF reader', () {
    test('reports the weakest LOAD alignment, not the strongest', () {
      // One 4 KB segment fails the library however well aligned the rest are,
      // which is why the minimum is the number that matters.
      final elf = Elf.parse(
        _elf64(const [(type: 1, align: 0x4000), (type: 1, align: 0x1000)]),
      );

      expect(elf.is64Bit, isTrue);
      expect(elf.loadAlignments, [0x4000, 0x1000]);
      expect(elf.minimumLoadAlignment, 0x1000);
    });

    test('ignores segments that are not PT_LOAD', () {
      // PT_DYNAMIC and friends are aligned to a word and would otherwise drag
      // the minimum down to 8, failing every library ever built.
      final elf = Elf.parse(
        _elf64(const [
          (type: 2, align: 8),
          (type: 1, align: 0x4000),
          (type: 6, align: 8),
        ]),
      );

      expect(elf.loadAlignments, [0x4000]);
      expect(elf.minimumLoadAlignment, 0x4000);
    });

    test('reads a 32-bit library too', () {
      // The program-header layout differs: p_align sits at +28 in a 32-bit
      // header and +48 in a 64-bit one. Reading one with the other's offsets
      // yields a plausible-looking number, so this is not a cosmetic case.
      final elf = Elf.parse(
        _elf32(const [(type: 1, align: 0x1000), (type: 1, align: 0x4000)]),
      );

      expect(elf.is64Bit, isFalse);
      expect(elf.minimumLoadAlignment, 0x1000);
    });

    test('has no alignment to report when there is no LOAD segment', () {
      expect(Elf.parse(_elf64(const [])).minimumLoadAlignment, isNull);
    });

    test('refuses what it does not understand instead of guessing', () {
      expect(
        () => Elf.parse(Uint8List.fromList(List.filled(64, 0))),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Elf.parse(Uint8List.fromList([0x7F, 0x45, 0x4C, 0x46])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('the ZIP reader', () {
    test('takes the data offset from the local header, not the central one', () {
      // This is the bug the reader exists to avoid. zipalign pads the **local**
      // extra field to push a library onto a 16 KB boundary, and the central
      // directory keeps its own, shorter copy. Computing the offset from the
      // central record therefore reports a misalignment that is not there — or
      // worse, an alignment that is.
      final zip = ZipIndex.read(
        _zip([
          _Member(
            name: 'lib/arm64-v8a/libtest.so',
            content: Uint8List.fromList([1, 2, 3, 4]),
            localExtraPadding: 7,
          ),
        ]),
      );

      final entry = zip.entries.single;
      expect(entry.isStored, isTrue);
      expect(
        zip.dataOffsetOf(entry),
        30 + entry.name.length + 7,
        reason: 'the 7 bytes of local padding were not accounted for',
      );
      expect(zip.contentOf(entry), [1, 2, 3, 4]);
    });

    test('inflates a deflated entry', () {
      // Everything in an .aab is deflated, so without this the bundle's
      // libraries cannot be read at all.
      final content = Uint8List.fromList(utf8.encode('x' * 500));
      final zip = ZipIndex.read(
        _zip([_Member(name: 'a.bin', content: content, deflate: true)]),
      );

      final entry = zip.entries.single;
      expect(entry.isDeflated, isTrue);
      expect(entry.compressedSize, lessThan(content.length));
      expect(zip.contentOf(entry), content);
    });

    test('finds every entry, and rejects what is not a ZIP', () {
      final zip = ZipIndex.read(
        _zip([
          _Member(name: 'one', content: Uint8List.fromList([1])),
          _Member(name: 'two', content: Uint8List.fromList([2])),
        ]),
      );

      expect(zip.entries.map((entry) => entry.name), ['one', 'two']);
      expect(
        () => ZipIndex.read(Uint8List.fromList(List.filled(200, 0))),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('the BundleConfig.pb reader', () {
    test('reads what AGP 8.11.1 actually wrote', () {
      // Not a hand-built message: these are the first bytes of the
      // BundleConfig.pb inside build/app/outputs/bundle/prodRelease, taken
      // from the 1.0.0+6 bundle of 2026-10-08. Fixing the expectation to a
      // real artifact is the point — a reader that agrees with a message this
      // test also wrote proves nothing about the one Play reads.
      final real = Uint8List.fromList([
        0x0A, 0x08, 0x12, 0x06, // bundletool { version: "1.18.1" }
        0x31, 0x2E, 0x31, 0x38, 0x2E, 0x31,
        0x12, 0x0C, // optimizations {
        0x0A, 0x00, //   splits_config {}
        0x12, 0x04, //   uncompress_native_libraries {
        0x08, 0x01, //     enabled: true
        0x10, 0x02, //     page_alignment: PAGE_ALIGNMENT_16K
        0x32, 0x02, //   uncompress_dex_files {
        0x08, 0x01, //     enabled: true
      ]);

      final config = BundleConfig.parse(real);
      expect(config.uncompressEnabled, isTrue);
      expect(config.pageAlignment, kPageAlignment16K);
      expect(kPageAlignmentNames[config.pageAlignment], 'PAGE_ALIGNMENT_16K');
    });

    test('a 4 KB bundle is not mistaken for a 16 KB one', () {
      // The failure this whole tool is for: `enabled` set, alignment at the
      // old default. Everything looks configured and nothing is 16 KB.
      final config = BundleConfig.parse(
        Uint8List.fromList([
          0x12, 0x08, // optimizations {
          0x12, 0x04, //   uncompress_native_libraries {
          0x08, 0x01, //     enabled: true
          0x10, 0x01, //     page_alignment: PAGE_ALIGNMENT_4K
          0x32, 0x02, //   uncompress_dex_files { enabled: true }
          0x08, 0x01,
        ]),
      );

      expect(config.uncompressEnabled, isTrue);
      expect(config.pageAlignment, isNot(kPageAlignment16K));
      expect(kPageAlignmentNames[config.pageAlignment], 'PAGE_ALIGNMENT_4K');
    });

    test('an absent field reads as unset, not as compliant', () {
      // A reader that returns 16 KB for a message it failed to parse is worse
      // than no reader.
      expect(BundleConfig.parse(Uint8List(0)).uncompressEnabled, isFalse);
      expect(BundleConfig.parse(Uint8List(0)).pageAlignment, 0);

      // optimizations {} — present but empty.
      final empty = BundleConfig.parse(Uint8List.fromList([0x12, 0x00]));
      expect(empty.uncompressEnabled, isFalse);
      expect(empty.pageAlignment, 0);
    });
  });

  test('the release-time check is documented', () {
    // A tool nobody knows to run is not a check. docs/BUILD.md is where
    // whoever cuts the release looks.
    expect(
      File('docs/BUILD.md').readAsStringSync(),
      contains('check_play_compliance'),
      reason: 'the Play compliance check must be in the release instructions',
    );
  });
}

/// Where the Flutter SDK that builds this project lives.
///
/// `FLUTTER_ROOT` is set by `flutter test` (on CI as well as locally). The
/// other two are fallbacks for being run by something else: `flutter_tester`
/// sits at `<root>/bin/cache/artifacts/engine/<platform>/`, and
/// `android/local.properties` names the SDK for Gradle.
String _flutterRoot() {
  final fromEnvironment = Platform.environment['FLUTTER_ROOT'];
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }

  final executable = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final cache = executable.indexOf('/bin/cache/');
  if (cache > 0) return executable.substring(0, cache);

  final properties = File('android/local.properties');
  if (properties.existsSync()) {
    for (final line in properties.readAsLinesSync()) {
      if (line.startsWith('flutter.sdk=')) {
        return line
            .substring('flutter.sdk='.length)
            .trim()
            .replaceAll(r'\\', '/');
      }
    }
  }

  fail(
    'cannot locate the Flutter SDK: FLUTTER_ROOT is unset, '
    '${Platform.resolvedExecutable} is not inside one, and '
    'android/local.properties does not name one',
  );
}

/// True when [permission] appears in the manifest only to be removed.
bool _removedByTheManifest(String manifest, String permission) => RegExp(
  '<uses-permission\\s+android:name="${RegExp.escape(permission)}"'
  '\\s+tools:node="remove"',
).hasMatch(manifest);

// ---------------------------------------------------------------------------
// Hand-built inputs
// ---------------------------------------------------------------------------

typedef _Segment = ({int type, int align});

/// A minimal ELF64 shared object: header plus [segments] program headers.
Uint8List _elf64(List<_Segment> segments) {
  const headerSize = 64;
  const entrySize = 56;
  final bytes = Uint8List(headerSize + entrySize * segments.length);
  final data = ByteData.sublistView(bytes);

  bytes.setAll(0, [0x7F, 0x45, 0x4C, 0x46, 2, 1]); // magic, ELF64, LSB
  data.setUint16(0x10, 3, Endian.little); // e_type = ET_DYN
  data.setUint64(0x20, headerSize, Endian.little); // e_phoff
  data.setUint16(0x36, entrySize, Endian.little); // e_phentsize
  data.setUint16(0x38, segments.length, Endian.little); // e_phnum

  for (var i = 0; i < segments.length; i++) {
    final at = headerSize + i * entrySize;
    data.setUint32(at, segments[i].type, Endian.little); // p_type
    data.setUint64(at + 48, segments[i].align, Endian.little); // p_align
  }
  return bytes;
}

/// The same, 32-bit: a 52-byte header and 32-byte program headers, with
/// `p_align` at +28 instead of +48.
Uint8List _elf32(List<_Segment> segments) {
  const headerSize = 52;
  const entrySize = 32;
  // Padded to 64 bytes so the reader's "is this long enough to be an ELF"
  // guard is not what the test is measuring.
  final length = headerSize + entrySize * segments.length;
  final bytes = Uint8List(length < 64 ? 64 : length);
  final data = ByteData.sublistView(bytes);

  bytes.setAll(0, [0x7F, 0x45, 0x4C, 0x46, 1, 1]); // magic, ELF32, LSB
  data.setUint16(0x10, 3, Endian.little); // e_type
  data.setUint32(0x1C, headerSize, Endian.little); // e_phoff
  data.setUint16(0x2A, entrySize, Endian.little); // e_phentsize
  data.setUint16(0x2C, segments.length, Endian.little); // e_phnum

  for (var i = 0; i < segments.length; i++) {
    final at = headerSize + i * entrySize;
    data.setUint32(at, segments[i].type, Endian.little); // p_type
    data.setUint32(at + 28, segments[i].align, Endian.little); // p_align
  }
  return bytes;
}

/// One member of a hand-built ZIP.
class _Member {
  _Member({
    required this.name,
    required this.content,
    this.deflate = false,
    this.localExtraPadding = 0,
  });

  final String name;
  final Uint8List content;
  final bool deflate;

  /// Bytes of extra field written into the **local** header only — what
  /// zipalign uses to push an entry onto a page boundary.
  final int localExtraPadding;
}

/// Builds a ZIP archive in memory.
///
/// Written here rather than taken from a package: the reader under test is
/// hand-written precisely because no package exposes local-header offsets, so
/// its test has to write the bytes too. CRCs are left at zero — the reader
/// does not check them, and an archive this test wrote is not something any
/// other tool reads.
Uint8List _zip(List<_Member> members) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  final offsets = <int>[];

  for (final member in members) {
    final name = utf8.encode(member.name);
    final stored = member.deflate
        ? Uint8List.fromList(ZLibCodec(raw: true).encode(member.content))
        : member.content;

    offsets.add(out.length);
    out.add(_u32(0x04034b50)); // local header signature
    out.add(_u16(20)); // version needed
    out.add(_u16(0)); // flags
    out.add(_u16(member.deflate ? 8 : 0)); // compression method
    out.add(_u16(0)); // time
    out.add(_u16(0)); // date
    out.add(_u32(0)); // crc32
    out.add(_u32(stored.length)); // compressed size
    out.add(_u32(member.content.length)); // uncompressed size
    out.add(_u16(name.length));
    out.add(_u16(member.localExtraPadding));
    out.add(name);
    out.add(Uint8List(member.localExtraPadding));
    out.add(stored);
  }

  for (var i = 0; i < members.length; i++) {
    final member = members[i];
    final name = utf8.encode(member.name);
    final stored = member.deflate
        ? Uint8List.fromList(ZLibCodec(raw: true).encode(member.content))
        : member.content;

    central.add(_u32(0x02014b50)); // central header signature
    central.add(_u16(20)); // version made by
    central.add(_u16(20)); // version needed
    central.add(_u16(0)); // flags
    central.add(_u16(member.deflate ? 8 : 0)); // compression method
    central.add(_u16(0)); // time
    central.add(_u16(0)); // date
    central.add(_u32(0)); // crc32
    central.add(_u32(stored.length));
    central.add(_u32(member.content.length));
    central.add(_u16(name.length));
    central.add(_u16(0)); // extra length: deliberately NOT the local one
    central.add(_u16(0)); // comment length
    central.add(_u16(0)); // disk number
    central.add(_u16(0)); // internal attributes
    central.add(_u32(0)); // external attributes
    central.add(_u32(offsets[i]));
    central.add(name);
  }

  final centralOffset = out.length;
  final centralBytes = central.toBytes();
  out.add(centralBytes);

  out.add(_u32(0x06054b50)); // end of central directory
  out.add(_u16(0)); // this disk
  out.add(_u16(0)); // disk with the central directory
  out.add(_u16(members.length)); // entries on this disk
  out.add(_u16(members.length)); // entries total
  out.add(_u32(centralBytes.length));
  out.add(_u32(centralOffset));
  out.add(_u16(0)); // comment length

  return out.toBytes();
}

Uint8List _u16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
