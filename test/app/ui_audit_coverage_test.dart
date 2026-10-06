import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// F27-T15: the layout sweep is only as good as its coverage, and nothing in
// Dart forces a new screen to opt into it. So this reads the screens off disk
// and the `auditScreenLayout` calls out of the test sources, and fails when a
// screen has no entry — the same shape of guard `native_permission_copy_test`
// uses for the native config.
void main() {
  final screenFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.replaceAll(r'\', '/').contains('/screens/'))
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// `class HomeScreen extends StatelessWidget` → `HomeScreen`. Only public
  /// top-level screen widgets count: a `_SomethingPage` private to one file
  /// is a part of its screen, not a route of its own.
  final classPattern = RegExp(
    r'^class (\w+Screen) extends (StatelessWidget|StatefulWidget)',
    multiLine: true,
  );

  final screens = <String, String>{};
  for (final file in screenFiles) {
    for (final match in classPattern.allMatches(file.readAsStringSync())) {
      screens[match.group(1)!] = file.path.replaceAll(r'\', '/');
    }
  }

  final audited = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .expand(
        (f) => RegExp(
          r"auditScreenLayout\(\s*'(\w+)'",
        ).allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
      )
      .toSet();

  test('every screen on disk was found', () {
    // A floor, not an exact count: the point is that the sweep below is
    // reading real files and not an empty directory listing.
    expect(screens.length, greaterThanOrEqualTo(18), reason: '$screens');
  });

  test('every screen is in the F27-T15 layout sweep', () {
    final missing = screens.keys.where((s) => !audited.contains(s)).toList()
      ..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'These screens have no `auditScreenLayout` entry, so nothing '
          'checks them for overflow at a phone size, in both languages, at '
          'large text:\n'
          '${missing.map((s) => '  · $s — ${screens[s]}').join('\n')}\n'
          'Add one to that screen\'s test file (see test/support/ui_audit.dart).',
    );
  });

  test('the sweep names no screen that no longer exists', () {
    final stale = audited.where((s) => !screens.containsKey(s)).toList()
      ..sort();

    expect(
      stale,
      isEmpty,
      reason:
          '`auditScreenLayout` is called with names that match no screen '
          'class under lib/**/screens/ — a rename left the sweep pointing at '
          'nothing: $stale',
    );
  });
}
