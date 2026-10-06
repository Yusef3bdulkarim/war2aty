import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F27-T13 · The release build's safety net, guarded.
///
/// None of this is Dart, so nothing else in the suite would notice it being
/// deleted — and each piece fails *silently* when it is missing, which is the
/// reason it was worth building:
///
/// - Without the key gate (H7), a prod release signs with the **debug key**
///   and produces an artifact that installs, runs, looks correct, and cannot
///   be published. Nobody finds out until Play rejects it, or until a tester
///   is handed it and trusts it.
/// - Without the asset strip (M4), the dev-only mock fixtures — canned
///   invoices and medical appointments — ship inside the real app.
///
/// These are text assertions on build files, which is a blunt instrument. It
/// is the only one available from a Dart test, and a blunt guard on a silent
/// failure is still worth more than no guard.
void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  group('a prod release cannot be signed with the debug key (H7)', () {
    test('the key gate is still in place', () {
      expect(
        gradle,
        contains('gradle.taskGraph.whenReady'),
        reason: 'the task-graph check is what fails the build',
      );
      expect(gradle, contains('releaseKeyProblem'));
      expect(
        gradle,
        contains('needs the real release key'),
        reason: 'the failure must say what is wrong, not just fail',
      );
    });

    test('it covers every task that produces or installs a prod release', () {
      // Named exactly rather than by a substring: `contains("ProdRelease")`
      // was the first attempt and it also matched the Flutter plugin's
      // `compileFlutterBuildProdRelease`, which is in *every* release graph —
      // so a dev release was refused too.
      for (final task in const [
        'assembleProdRelease',
        'bundleProdRelease',
        'packageProdRelease',
        'packageProdReleaseBundle',
        'installProdRelease',
      ]) {
        expect(
          gradle,
          contains('"$task"'),
          reason: '$task would bypass the key gate',
        );
      }
    });

    test('the keystore path is resolved from the module, not the root', () {
      // `storeFile` is relative to android/app/. Resolving it against the root
      // project made the check reject the real keystore — a build that failed
      // for the wrong reason, which is its own kind of broken.
      expect(
        gradle,
        contains('!file(keystoreProperties["storeFile"] as String).exists()'),
      );
    });

    test('the debug fallback is still reachable for dev', () {
      // Deliberate: `flutter run --release` on the dev flavor must keep
      // working on a machine with no keystore.
      expect(gradle, contains('signingConfigs.getByName("debug")'));
    });
  });

  group('dev-only fixtures stay out of the prod bundle (M4)', () {
    test('the strip is wired to the prod asset tasks', () {
      expect(
        gradle,
        contains('copyFlutterAssetsProd(Debug|Profile|Release)'),
        reason: 'the hook is what removes the fixtures',
      );
      expect(gradle, contains('flutter_assets/assets/fixtures'));
    });

    test('a renamed Flutter task fails the build instead of shipping them', () {
      expect(
        gradle,
        contains('prodAssetStripTasks.isEmpty()'),
        reason: 'a silent no-op here would quietly ship the fixtures again',
      );
    });

    test('the fixtures are still declared for dev', () {
      // The other half of the same contract: the mock datasource loads them
      // through `rootBundle`, so a dev build must still carry them.
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/fixtures/analysis/'),
      );
    });
  });

  group('Gradle memory settings (M8)', () {
    final properties = File('android/gradle.properties').readAsStringSync();

    test('the heap is bounded and the second JVM is gone', () {
      expect(properties, contains('-Xmx2G'));
      expect(
        properties,
        contains('kotlin.compiler.execution.strategy=in-process'),
        reason: 'one JVM instead of two on a memory-starved machine',
      );
    });

    test('no heap dump on OOM', () {
      // It cannot fire on the native OOM that actually happened, and when it
      // does fire it writes a multi-gigabyte file on a machine that is already
      // out of memory.
      //
      // Asserted on the `jvmargs` line rather than the whole file: the comment
      // above it names the flag in order to say why it was removed, and a
      // guard that cannot tell a setting from an explanation of a setting is
      // worse than none.
      final jvmArgs = properties
          .split(RegExp(r'\r?\n'))
          .firstWhere(
            (line) => line.startsWith('org.gradle.jvmargs='),
            orElse: () => '',
          );

      expect(jvmArgs, isNotEmpty, reason: 'org.gradle.jvmargs is not set');
      expect(jvmArgs, isNot(contains('HeapDumpOnOutOfMemoryError')));
      expect(jvmArgs, contains('-Xmx2G'));
    });

    test('the diagnosis is recorded where the next person will look', () {
      // Raising -Xmx is the obvious reaction and the wrong one: the failures
      // were native allocations on a full machine, and a bigger Java heap
      // squeezes the native heap further.
      expect(properties.toLowerCase(), contains('native'));
    });

    test('no crash dumps are left lying in the repo', () {
      final dumps = Directory('android')
          .listSync()
          .whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith('hs_err_pid'))
          .toList();

      expect(dumps, isEmpty, reason: 'stale OOM dumps: ${dumps.length}');
    });
  });

  test('the build is documented', () {
    // The flags are silent when forgotten, so the script and the document that
    // explains it are part of the deliverable, not decoration.
    expect(File('tool/build_release.ps1').existsSync(), isTrue);
    final doc = File('docs/BUILD.md').readAsStringSync();
    expect(doc, contains('--obfuscate'));
    expect(doc, contains('--split-debug-info'));
    expect(doc, contains('apksigner'));
  });
}
