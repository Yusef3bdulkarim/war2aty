// Quality gate: format -> analyze -> test.
//
// Runs the three checks in order and stops non-zero on the first failure,
// so it can be used as a pre-commit / CI gate. Portable across Windows,
// macOS, and Linux (run with `dart run tool/check.dart`).
import 'dart:io';

Future<void> main() async {
  final steps = <(String, List<String>)>[
    // Unformatted code fails the gate (does not silently reformat).
    ('dart', ['format', '--output=none', '--set-exit-if-changed', '.']),
    ('flutter', ['analyze']),
    ('flutter', ['test']),
  ];

  for (final (command, args) in steps) {
    final label = '$command ${args.join(' ')}';
    stdout.writeln('\n▶ $label');

    final process = await Process.start(
      command,
      args,
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );
    final code = await process.exitCode;

    if (code != 0) {
      stderr.writeln('\n✖ Quality gate failed at: $label (exit $code)');
      exit(code);
    }
  }

  stdout.writeln('\n✓ All checks passed.');
}
