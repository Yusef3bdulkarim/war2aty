// Checks a built Android artifact against the Play requirements that are
// properties of the artifact itself (F27-T19).
//
//   dart run tool/check_play_compliance.dart build/app/outputs/bundle/prodRelease/app-prod-release.aab
//   dart run tool/check_play_compliance.dart build/app/outputs/flutter-apk/app-prod-release.apk
//
// Why a tool and not a one-off reading of the numbers: three of the four things
// below are properties of files this repo does not build — `libtesseract.so`,
// `libleptonica.so`, `libjpeg.so`, `libpngx.so` and `libsqlite3.so` arrive as
// prebuilt binaries inside plugin AARs, and `libflutter.so` comes from the
// engine. A plugin upgrade can therefore break Play compliance without a single
// line of this project changing, and nothing in `flutter test` can see it: the
// evidence exists only inside a release artifact. So this runs against the
// artifact, at release time, and is listed in docs/BUILD.md.
//
// What is checked:
//
//   1. 16 KB page alignment — every LOAD segment of every 64-bit `.so` is
//      aligned to at least 16 KB (`p_align >= 2**14`). Required by Play for
//      apps targeting Android 15+; 16 KB page devices are 64-bit only, so the
//      32-bit libraries are reported but not required to comply.
//   2. The packaging that makes that alignment reachable at runtime — in an
//      APK, every `.so` stored uncompressed at a 16 KB boundary (what
//      `zipalign -c -P 16 4` checks); in an App Bundle, `BundleConfig.pb`
//      telling Play to produce exactly that when it splits the bundle.
//   3. Target SDK and the permission list (APK only — `aapt2` cannot read a
//      bundle). Permissions are matched against an allowlist that carries a
//      justification for each one, so a plugin contributing a new permission
//      fails here instead of appearing in the Play listing.
//   4. The artifact is not debuggable.
//
// Checks 3 and 4 need `aapt2` from the Android SDK. Without it they are
// reported as skipped rather than passed.
//
// The ELF and ZIP readers are deliberately hand-written and minimal: no new
// dependency (CLAUDE.md §B5), and no NDK on PATH, so this runs anywhere a
// checkout does.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Play's 16 KB page-size requirement, in bytes.
///
/// https://developer.android.com/guide/practices/page-sizes
const int kRequiredPageAlignment = 16 * 1024;

/// The target API level Play requires of a new app or an update.
///
/// Android 16, required since 2026-08-31. Raise this when Play does; the app
/// itself takes `targetSdk` from the Flutter SDK (see
/// `android/app/build.gradle.kts`), and `play_compliance_test` asserts that
/// what the SDK resolves to still clears this number.
const int kPlayRequiredTargetSdk = 36;

/// The 64-bit ABIs. Only these have to satisfy the 16 KB requirement: a 16 KB
/// page device is by definition 64-bit, and `armeabi-v7a` code never runs on
/// one.
const Set<String> kAbis64Bit = {'arm64-v8a', 'x86_64'};

/// The 32-bit ABIs, listed so that an ABI belonging to neither set can be
/// *reported* rather than waved through. Without this, a `.so` the reader
/// cannot place — anywhere outside `lib/<abi>/` — would be treated as 32-bit
/// and so exempt, which is the one way this check could pass a library it
/// never examined.
const Set<String> kAbis32Bit = {'armeabi-v7a', 'x86'};

/// Every permission the prod release may declare, and why.
///
/// Five are ours and are justified in `android/app/src/main/AndroidManifest.xml`
/// (and guarded by `android_permissions_test`, which reads that file). The last
/// three are contributed by plugins and appear only after the manifest merge,
/// which is why no test over the source tree can see them and why they are
/// listed here instead.
const Map<String, String> kAllowedPermissions = {
  'android.permission.CAMERA': 'the user photographs a paper',
  'android.permission.INTERNET': 'Supabase auth and the two Edge Functions',
  'android.permission.POST_NOTIFICATIONS': 'reminder alerts on Android 13+',
  'android.permission.RECEIVE_BOOT_COMPLETED':
      're-arm scheduled reminders after a reboot',
  'android.permission.WAKE_LOCK': 'deliver a reminder on a sleeping device',
  'android.permission.ACCESS_NETWORK_STATE':
      'contributed by connectivity_plus; used — the online/offline route '
      'decision reads it',
  'android.permission.VIBRATE':
      'contributed by flutter_local_notifications; used — the reminder channel '
      'vibrates (AndroidNotificationDetails defaults to enableVibration: true)',
  'DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION':
      'contributed by androidx.core; a signature-level permission the library '
      'declares for its own non-exported receivers, prefixed with the '
      'application id, and not grantable to anything else',
};

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tool/check_play_compliance.dart <path to .aab or .apk>',
    );
    exit(64);
  }

  final path = args.single;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('✖ $path does not exist. Build it first (docs/BUILD.md).');
    exit(66);
  }

  final isBundle = path.toLowerCase().endsWith('.aab');
  final bytes = file.readAsBytesSync();
  final archive = ZipIndex.read(bytes);

  stdout.writeln('Play compliance check (F27-T19)');
  stdout.writeln('  artifact: $path');
  stdout.writeln(
    '  size:     ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB '
    '(${bytes.length} bytes)',
  );
  stdout.writeln('  kind:     ${isBundle ? 'App Bundle' : 'APK'}');
  stdout.writeln();

  final failures = <String>[];

  _checkNativeLibraries(archive, isBundle: isBundle, failures: failures);
  if (isBundle) {
    _checkBundleConfig(archive, failures);
  }
  _checkWithAapt2(path, isBundle: isBundle, failures: failures);

  stdout.writeln();
  if (failures.isEmpty) {
    stdout.writeln('✓ every check passed');
    exit(0);
  }
  stderr.writeln('✖ ${failures.length} check(s) failed:');
  for (final failure in failures) {
    stderr.writeln('  · $failure');
  }
  exit(1);
}

// ---------------------------------------------------------------------------
// 1 + 2 · native libraries
// ---------------------------------------------------------------------------

void _checkNativeLibraries(
  ZipIndex archive, {
  required bool isBundle,
  required List<String> failures,
}) {
  final libraries =
      archive.entries.where((entry) => entry.name.endsWith('.so')).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  if (libraries.isEmpty) {
    failures.add(
      'no .so found in the artifact — the reader is looking in the wrong '
      'place, or this is not an Android artifact',
    );
    return;
  }

  stdout.writeln('Native libraries (${libraries.length}):');

  for (final entry in libraries) {
    final abi = abiOf(entry.name);
    final required64 = kAbis64Bit.contains(abi);
    if (!required64 && !kAbis32Bit.contains(abi)) {
      failures.add(
        '${entry.name}: cannot tell which ABI this is ("$abi"), so whether '
        'the 16 KB requirement applies is unknown — do not assume it does '
        'not',
      );
    }

    final Elf elf;
    try {
      elf = Elf.parse(archive.contentOf(entry));
    } on FormatException catch (error) {
      failures.add('${entry.name}: not readable as ELF — ${error.message}');
      continue;
    }

    final align = elf.minimumLoadAlignment;
    final alignOk = align != null && align >= kRequiredPageAlignment;
    final notes = <String>['align ${_alignLabel(align)}'];

    // Packaging. In an APK it is observable: the entry must be stored (not
    // deflated) and begin on a 16 KB boundary, which is what a 16 KB device
    // needs to map the library straight out of the APK. In a bundle it is not
    // — Play repackages — so the bundle is checked through BundleConfig.pb
    // instead, once, below.
    var packagingOk = true;
    if (!isBundle) {
      final offset = archive.dataOffsetOf(entry);
      if (entry.isDeflated) {
        packagingOk = false;
        notes.add('COMPRESSED');
      } else if (offset % kRequiredPageAlignment != 0) {
        packagingOk = false;
        notes.add('offset $offset not 16 KB aligned');
      } else {
        notes.add('stored at $offset');
      }
    }

    final ok = packagingOk && (alignOk || !required64);
    final verdict = ok
        ? (required64 ? 'OK' : 'ok (32-bit, not required)')
        : 'FAIL';
    stdout.writeln('  [$verdict] ${entry.name}  (${notes.join(', ')})');

    if (required64 && !alignOk) {
      failures.add(
        '${entry.name}: LOAD segments aligned to ${_alignLabel(align)}, '
        'needs at least 16 KB (2**14) — Play rejects this on a 64-bit ABI',
      );
    }
    if (!packagingOk) {
      failures.add(
        '${entry.name}: not stored uncompressed on a 16 KB boundary — check '
        '`useLegacyPackaging` / `extractNativeLibs` and the AGP version',
      );
    }
  }
}

/// The ABI directory an entry sits in.
///
/// `lib/<abi>/x.so` in an APK, `base/lib/<abi>/x.so` in a bundle.
String abiOf(String entryName) {
  final parts = entryName.split('/');
  return parts.length >= 2 ? parts[parts.length - 2] : '?';
}

String _alignLabel(int? align) {
  if (align == null) return 'no LOAD segment';
  final exponent = align.bitLength - 1;
  final isPowerOfTwo = align > 0 && (align & (align - 1)) == 0;
  final kb = align / 1024;
  return isPowerOfTwo
      ? '2**$exponent (${kb.toStringAsFixed(kb % 1 == 0 ? 0 : 1)} KB)'
      : '$align bytes';
}

// ---------------------------------------------------------------------------
// 2 · the bundle's instruction to Play
// ---------------------------------------------------------------------------

/// `BundleConfig.PageAlignment` (bundletool's `config.proto`), as of
/// bundletool 1.18.1. Verified against the enum compiled into the bundletool
/// jar rather than assumed.
const Map<int, String> kPageAlignmentNames = {
  0: 'PAGE_ALIGNMENT_UNSPECIFIED',
  1: 'PAGE_ALIGNMENT_4K',
  2: 'PAGE_ALIGNMENT_16K',
  3: 'PAGE_ALIGNMENT_64K',
};

/// The enum value that means 16 KB.
const int kPageAlignment16K = 2;

void _checkBundleConfig(ZipIndex archive, List<String> failures) {
  stdout.writeln();
  stdout.writeln('BundleConfig.pb (what Play is told to do when it splits):');

  final entry = archive.entries
      .where((candidate) => candidate.name == 'BundleConfig.pb')
      .firstOrNull;
  if (entry == null) {
    failures.add('BundleConfig.pb is missing from the bundle');
    return;
  }

  final config = BundleConfig.parse(archive.contentOf(entry));
  final alignment = config.pageAlignment;
  final name = kPageAlignmentNames[alignment] ?? 'unknown ($alignment)';

  stdout.writeln(
    '  uncompressNativeLibraries.enabled        = ${config.uncompressEnabled}',
  );
  stdout.writeln('  uncompressNativeLibraries.pageAlignment  = $name');

  // Both halves matter. Without `enabled` the libraries are delivered
  // compressed and have to be extracted at install time, so the alignment
  // inside the APK is irrelevant and the 16 KB mapping never happens; with it
  // but at 4 KB, the libraries are uncompressed and misaligned.
  if (!config.uncompressEnabled) {
    failures.add(
      'the bundle does not ask Play to store native libraries uncompressed '
      '(uncompressNativeLibraries.enabled is false)',
    );
  }
  if (alignment != kPageAlignment16K) {
    failures.add(
      'the bundle asks Play for $name, not PAGE_ALIGNMENT_16K — AGP 8.5.1+ '
      'writes 16K; check the AGP version in android/settings.gradle.kts',
    );
  }
}

// ---------------------------------------------------------------------------
// 3 + 4 · what only aapt2 can answer
// ---------------------------------------------------------------------------

void _checkWithAapt2(
  String path, {
  required bool isBundle,
  required List<String> failures,
}) {
  stdout.writeln();
  stdout.writeln('Manifest (target SDK, permissions, debuggable):');

  if (isBundle) {
    // Not a gap in coverage: the APK and the bundle are packaged from the same
    // merged manifest, so the APK built from the same commit answers for both.
    stdout.writeln(
      '  skipped — aapt2 cannot read an .aab ("could not identify format of '
      'APK"). Run this against the prod APK of the same commit; both are '
      'packaged from the same merged manifest.',
    );
    return;
  }

  final aapt2 = _findAapt2();
  if (aapt2 == null) {
    stdout.writeln(
      '  skipped — aapt2 not found. Set ANDROID_HOME, or sdk.dir in '
      'android/local.properties.',
    );
    return;
  }

  final badging = Process.runSync(aapt2, [
    'dump',
    'badging',
    path,
  ], stdoutEncoding: utf8);
  if (badging.exitCode != 0) {
    failures.add('aapt2 dump badging failed: ${badging.stderr}');
    return;
  }
  final lines = (badging.stdout as String).split('\n');

  // Target SDK.
  final targetSdk = _firstMatch(lines, RegExp(r"^targetSdkVersion:'(\d+)'"));
  stdout.writeln('  targetSdkVersion = ${targetSdk ?? 'not declared'}');
  final target = int.tryParse(targetSdk ?? '');
  if (target == null || target < kPlayRequiredTargetSdk) {
    failures.add(
      'targetSdkVersion is ${targetSdk ?? 'absent'}; Play requires at least '
      '$kPlayRequiredTargetSdk',
    );
  }

  // Permissions.
  final declared = lines
      .map(
        (line) => RegExp(r"^uses-permission: name='([^']+)'").firstMatch(line),
      )
      .nonNulls
      .map((match) => match.group(1)!)
      .toSet();
  stdout.writeln('  permissions (${declared.length}):');
  // The androidx permission is prefixed with the application id, which differs
  // between the dev and prod flavors, so it cannot be allowlisted by its full
  // name. It is matched on its suffix — but only under *this* package's
  // prefix, read from the artifact: a bare `endsWith` would also accept
  // `com.someone.else.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` arriving from
  // a dependency nobody reviewed.
  final package = _firstMatch(lines, RegExp(r"^package: name='([^']+)'"));

  for (final permission in declared.toList()..sort()) {
    final key = kAllowedPermissions.containsKey(permission)
        ? permission
        : kAllowedPermissions.keys
              .where(
                (allowed) =>
                    package != null && permission == '$package.$allowed',
              )
              .firstOrNull;
    if (key == null) {
      stdout.writeln('    [FAIL] $permission — not in the allowlist');
      failures.add(
        '$permission is declared but not in kAllowedPermissions: decide '
        'whether the app should ask for it, then justify it there or remove '
        'it from the manifest',
      );
    } else {
      stdout.writeln('    [ok]   $permission — ${kAllowedPermissions[key]}');
    }
  }

  // Debuggable.
  final debuggable = lines.any(
    (line) => line.startsWith('application-debuggable'),
  );
  stdout.writeln('  debuggable = $debuggable');
  if (debuggable) {
    failures.add('the artifact is debuggable and must never be published');
  }

  // Native libraries are mapped from the APK rather than extracted. Checked
  // here because it is the manifest attribute that decides it, and because the
  // 16 KB offsets above are meaningless without it.
  final xmltree = Process.runSync(aapt2, [
    'dump',
    'xmltree',
    '--file',
    'AndroidManifest.xml',
    path,
  ], stdoutEncoding: utf8);
  if (xmltree.exitCode != 0) {
    // Without this the empty output below reads as "the attribute is not
    // set", which is a true failure for a false reason.
    failures.add('aapt2 dump xmltree failed: ${xmltree.stderr}');
    return;
  }
  final extract = RegExp(
    r'android:extractNativeLibs\([^)]*\)=([^\s]+)',
  ).firstMatch(xmltree.stdout as String)?.group(1);
  stdout.writeln('  extractNativeLibs = ${extract ?? 'not set'}');
  if (extract != 'false') {
    failures.add(
      'extractNativeLibs is ${extract ?? 'not set'}; it must be false so the '
      'libraries are mapped straight out of the APK at their aligned offsets',
    );
  }
}

String? _firstMatch(List<String> lines, RegExp pattern) {
  for (final line in lines) {
    final match = pattern.firstMatch(line.trim());
    if (match != null) return match.group(1);
  }
  return null;
}

/// Locates `aapt2` in the Android SDK, newest build-tools first.
String? _findAapt2() {
  final roots = <String>[
    ...[
      'ANDROID_HOME',
      'ANDROID_SDK_ROOT',
    ].map((name) => Platform.environment[name]).nonNulls,
    ?_sdkDirFromLocalProperties(),
  ];

  for (final root in roots) {
    final buildTools = Directory('$root/build-tools');
    if (!buildTools.existsSync()) continue;
    final versions = buildTools.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final version in versions) {
      for (final name in ['aapt2.exe', 'aapt2']) {
        final candidate = File('${version.path}/$name');
        if (candidate.existsSync()) return candidate.path;
      }
    }
  }
  return null;
}

String? _sdkDirFromLocalProperties() {
  final file = File('android/local.properties');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('sdk.dir=')) {
      // Gradle properties escape Windows separators.
      return line.substring('sdk.dir='.length).trim().replaceAll(r'\\', '/');
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// ELF
// ---------------------------------------------------------------------------

/// Just enough of ELF to answer "how are the LOAD segments aligned".
class Elf {
  Elf._(this.is64Bit, this.loadAlignments);

  final bool is64Bit;

  /// `p_align` of every `PT_LOAD` program header, in order.
  final List<int> loadAlignments;

  static const int _ptLoad = 1;

  factory Elf.parse(Uint8List bytes) {
    if (bytes.length < 64) {
      throw const FormatException('shorter than an ELF header');
    }
    if (bytes[0] != 0x7F ||
        bytes[1] != 0x45 ||
        bytes[2] != 0x4C ||
        bytes[3] != 0x46) {
      throw const FormatException('no ELF magic');
    }
    final is64Bit = switch (bytes[4]) {
      1 => false,
      2 => true,
      _ => throw FormatException('unknown EI_CLASS ${bytes[4]}'),
    };
    if (bytes[5] != 1) {
      // Every Android ABI is little-endian; a big-endian file here means the
      // reader is being pointed at something it does not understand.
      throw FormatException('not little-endian (EI_DATA ${bytes[5]})');
    }

    final data = ByteData.sublistView(bytes);
    const endian = Endian.little;

    final phoff = is64Bit
        ? data.getUint64(0x20, endian)
        : data.getUint32(0x1C, endian);
    final phentsize = is64Bit
        ? data.getUint16(0x36, endian)
        : data.getUint16(0x2A, endian);
    final phnum = is64Bit
        ? data.getUint16(0x38, endian)
        : data.getUint16(0x2C, endian);

    final alignments = <int>[];
    for (var i = 0; i < phnum; i++) {
      final offset = phoff + i * phentsize;
      if (offset + phentsize > bytes.length) {
        throw const FormatException('program header table runs past the file');
      }
      if (data.getUint32(offset, endian) != _ptLoad) continue;
      alignments.add(
        is64Bit
            ? data.getUint64(offset + 48, endian)
            : data.getUint32(offset + 28, endian),
      );
    }
    return Elf._(is64Bit, alignments);
  }

  /// The weakest alignment any LOAD segment has, or null when there is none.
  ///
  /// The weakest rather than the strongest on purpose: the requirement is that
  /// *every* LOAD segment can be mapped on a 16 KB boundary, so one 4 KB
  /// segment fails the library however well aligned the rest are.
  int? get minimumLoadAlignment => loadAlignments.isEmpty
      ? null
      : loadAlignments.reduce((a, b) => a < b ? a : b);
}

// ---------------------------------------------------------------------------
// ZIP
// ---------------------------------------------------------------------------

/// One central-directory record.
class ZipEntry {
  ZipEntry({
    required this.name,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });

  final String name;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;

  static const int _stored = 0;
  static const int _deflated = 8;

  bool get isStored => compressionMethod == _stored;
  bool get isDeflated => compressionMethod == _deflated;
}

/// A read-only view over a ZIP held in memory.
///
/// Hand-written because the two things this tool needs are the two things a
/// convenience API usually hides: the *offset* at which an entry's bytes begin
/// (16 KB alignment is a property of that offset) and whether the entry is
/// stored or deflated. An APK is ~40 MB and a bundle ~70 MB, so holding it in
/// memory is cheaper than the code to avoid it.
class ZipIndex {
  ZipIndex._(this._bytes, this.entries);

  final Uint8List _bytes;
  final List<ZipEntry> entries;

  static const int _eocdSignature = 0x06054b50;
  static const int _centralSignature = 0x02014b50;
  static const int _localSignature = 0x04034b50;

  factory ZipIndex.read(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);

    // The end-of-central-directory record sits at the end, behind a comment of
    // up to 64 KB.
    var eocd = -1;
    final floor = bytes.length - 22 - 0xFFFF;
    for (var i = bytes.length - 22; i >= (floor < 0 ? 0 : floor); i--) {
      if (data.getUint32(i, Endian.little) == _eocdSignature) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) {
      throw const FormatException('not a ZIP: no end-of-central-directory');
    }

    final count = data.getUint16(eocd + 10, Endian.little);
    var offset = data.getUint32(eocd + 16, Endian.little);
    if (offset == 0xFFFFFFFF || count == 0xFFFF) {
      // No Android artifact is this big; refuse rather than mis-read it.
      throw const FormatException('ZIP64 archives are not supported');
    }

    final entries = <ZipEntry>[];
    for (var i = 0; i < count; i++) {
      if (data.getUint32(offset, Endian.little) != _centralSignature) {
        throw FormatException('bad central directory record at $offset');
      }
      final nameLength = data.getUint16(offset + 28, Endian.little);
      final extraLength = data.getUint16(offset + 30, Endian.little);
      final commentLength = data.getUint16(offset + 32, Endian.little);
      entries.add(
        ZipEntry(
          name: utf8.decode(
            bytes.sublist(offset + 46, offset + 46 + nameLength),
          ),
          compressionMethod: data.getUint16(offset + 10, Endian.little),
          compressedSize: data.getUint32(offset + 20, Endian.little),
          uncompressedSize: data.getUint32(offset + 24, Endian.little),
          localHeaderOffset: data.getUint32(offset + 42, Endian.little),
        ),
      );
      offset += 46 + nameLength + extraLength + commentLength;
    }
    return ZipIndex._(bytes, entries);
  }

  /// Where an entry's bytes actually start.
  ///
  /// Read from the **local** header, not the central one: the padding zipalign
  /// inserts to put a library on a 16 KB boundary lives in the local extra
  /// field, so the central directory's copy cannot be used to compute this.
  int dataOffsetOf(ZipEntry entry) {
    final data = ByteData.sublistView(_bytes);
    final at = entry.localHeaderOffset;
    if (data.getUint32(at, Endian.little) != _localSignature) {
      throw FormatException('bad local header for ${entry.name} at $at');
    }
    final nameLength = data.getUint16(at + 26, Endian.little);
    final extraLength = data.getUint16(at + 28, Endian.little);
    return at + 30 + nameLength + extraLength;
  }

  /// The entry's bytes, inflating a deflated entry.
  Uint8List contentOf(ZipEntry entry) {
    final start = dataOffsetOf(entry);
    final raw = Uint8List.sublistView(
      _bytes,
      start,
      start + entry.compressedSize,
    );
    if (entry.isStored) return raw;
    if (entry.isDeflated) {
      return Uint8List.fromList(ZLibCodec(raw: true).decode(raw));
    }
    throw FormatException(
      'unsupported compression method ${entry.compressionMethod} '
      'for ${entry.name}',
    );
  }
}

// ---------------------------------------------------------------------------
// BundleConfig.pb
// ---------------------------------------------------------------------------

/// The two fields of `BundleConfig.pb` that decide how Play packages native
/// libraries.
///
/// Read with a minimal protobuf field walker rather than generated code: the
/// schema is bundletool's, nothing in this project depends on it, and the two
/// fields needed are a bool and an enum two levels down:
///
///   BundleConfig.optimizations               = field 2
///   Optimizations.uncompress_native_libraries = field 2
///   UncompressNativeLibraries.enabled         = field 1 (bool)
///   UncompressNativeLibraries.page_alignment  = field 2 (enum)
class BundleConfig {
  BundleConfig._(this.uncompressEnabled, this.pageAlignment);

  final bool uncompressEnabled;

  /// The `PageAlignment` enum value, or 0 (`UNSPECIFIED`) when absent.
  final int pageAlignment;

  factory BundleConfig.parse(Uint8List bytes) {
    final optimizations = _submessage(bytes, 2);
    if (optimizations == null) return BundleConfig._(false, 0);
    final uncompress = _submessage(optimizations, 2);
    if (uncompress == null) return BundleConfig._(false, 0);
    return BundleConfig._(
      (_varint(uncompress, 1) ?? 0) != 0,
      _varint(uncompress, 2) ?? 0,
    );
  }

  /// The length-delimited value of [field], or null.
  static Uint8List? _submessage(Uint8List bytes, int field) =>
      _walk(bytes, field, wireType: 2) as Uint8List?;

  /// The varint value of [field], or null.
  static int? _varint(Uint8List bytes, int field) =>
      _walk(bytes, field, wireType: 0) as int?;

  static Object? _walk(Uint8List bytes, int field, {required int wireType}) {
    var at = 0;
    while (at < bytes.length) {
      final (tag, afterTag) = _readVarint(bytes, at);
      final number = tag >> 3;
      final type = tag & 7;
      var cursor = afterTag;

      switch (type) {
        case 0:
          final (value, next) = _readVarint(bytes, cursor);
          if (number == field && wireType == 0) return value;
          cursor = next;
        case 2:
          final (length, afterLength) = _readVarint(bytes, cursor);
          if (number == field && wireType == 2) {
            return Uint8List.sublistView(
              bytes,
              afterLength,
              afterLength + length,
            );
          }
          cursor = afterLength + length;
        case 5:
          cursor += 4;
        case 1:
          cursor += 8;
        default:
          // A group or an unknown wire type: stop rather than guess, so a
          // mis-read never looks like a missing field.
          throw FormatException('unsupported protobuf wire type $type');
      }
      at = cursor;
    }
    return null;
  }

  static (int, int) _readVarint(Uint8List bytes, int at) {
    var result = 0;
    var shift = 0;
    var cursor = at;
    while (cursor < bytes.length) {
      final byte = bytes[cursor++];
      result |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) return (result, cursor);
      shift += 7;
      if (shift > 63) throw const FormatException('varint too long');
    }
    throw const FormatException('truncated varint');
  }
}
