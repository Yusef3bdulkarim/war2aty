import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/voice/voice_line.dart';

/// F37-T20 · The fixed spoken lines, held to id ↔ line parity in **both**
/// directions.
///
/// This suite exists because of one specific failure: a line renamed in one
/// place and not the other ships as **silence**. For a user who cannot read the
/// screen, a silent failure screen is indistinguishable from a broken app, and
/// nothing else in the suite would notice — the enum would still compile, the
/// generator would still run, and the asset would simply never be found.
///
/// So three artifacts have to agree, and each direction is asserted separately:
///
/// 1. `docs/features/F37-voice-lines.md` — the owner's Arabic, and what the
///    generator reads.
/// 2. [VoiceLine] — the set of lines the app can speak.
/// 3. `assets/voice_lines/*.m4a` — the generated files, plus the `pubspec`
///    declaration that puts them in the bundle. A file that exists in the repo
///    but is not declared is not in the APK, and fails at runtime exactly like
///    a missing one.
///
/// The table is parsed the same way `generate-voice-lines.ts` parses it: a row
/// whose second cell is a backticked snake_case id. Keeping the two parsers
/// shaped alike means a table the test accepts is a table the generator will
/// read.
void main() {
  const tablePath = 'docs/features/F37-voice-lines.md';

  /// `{id: arabic}` from the Markdown table.
  final table = <String, String>{};

  setUpAll(() {
    final content = File(tablePath).readAsStringSync();
    final idCell = RegExp(r'^`([a-z0-9_]+)`$');

    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final row = raw.trim();
      if (!row.startsWith('|')) continue;

      final cells = row
          .split('|')
          .sublist(1)
          .map((c) => c.trim())
          .toList(growable: false);
      // `split` on a `|…|` row yields an empty first and last cell; drop the
      // trailing one, having already dropped the leading one.
      if (cells.length < 5) continue;

      final match = idCell.firstMatch(cells[1]);
      if (match == null) continue; // header, separator, or the rejected table

      table[match.group(1)!] = cells[2];
    }
  });

  group('the table and the enum', () {
    test('the table is found and not empty', () {
      // A table that silently stops parsing would make every assertion below
      // pass against nothing.
      expect(
        table,
        isNotEmpty,
        reason: 'no line rows parsed out of $tablePath — has it changed shape?',
      );
    });

    test('every table id has a VoiceLine', () {
      final missing = table.keys
          .where((id) => VoiceLine.byId(id) == null)
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'these ids are in $tablePath but not in VoiceLine, so nothing can '
            'ever play them: $missing',
      );
    });

    test('every VoiceLine has a table id', () {
      final missing = VoiceLine.values
          .where((line) => !table.containsKey(line.id))
          .map((line) => line.id)
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'these lines are in VoiceLine but not in $tablePath, so the '
            'generator will never produce their audio: $missing',
      );
    });

    test('the counts match exactly', () {
      expect(table.length, VoiceLine.values.length);
    });

    test('no table row has empty Arabic', () {
      final empty = table.entries
          .where((e) => e.value.isEmpty)
          .map((e) => e.key)
          .toList();
      expect(
        empty,
        isEmpty,
        reason: 'an empty text cell generates an empty audio file: $empty',
      );
    });
  });

  group('the ids themselves', () {
    test('are unique', () {
      final ids = VoiceLine.values.map((line) => line.id).toSet();
      expect(ids.length, VoiceLine.values.length);
    });

    test('are snake_case', () {
      // The id is a filename and a Markdown cell. Anything else breaks one of
      // the two parsers rather than failing loudly here.
      for (final line in VoiceLine.values) {
        expect(
          line.id,
          matches(RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$')),
          reason: '${line.name} has a non-snake_case id',
        );
      }
    });

    test('byId answers for every line and for nothing else', () {
      for (final line in VoiceLine.values) {
        expect(VoiceLine.byId(line.id), line);
      }
      expect(VoiceLine.byId('no_such_line'), isNull);
      expect(VoiceLine.byId(''), isNull);
    });
  });

  group('asset paths', () {
    test('are built from the id, not the Dart constant name', () {
      // Renaming a Dart constant must not be able to move a file path.
      for (final line in VoiceLine.values) {
        expect(line.assetPath, '${VoiceLine.assetDirectory}/${line.id}.m4a');
      }
    });

    test('are unique', () {
      final paths = VoiceLine.values.map((line) => line.assetPath).toSet();
      expect(paths.length, VoiceLine.values.length);
    });

    test('all sit under one directory', () {
      for (final line in VoiceLine.values) {
        expect(line.assetPath, startsWith('${VoiceLine.assetDirectory}/'));
      }
    });
  });

  group('the bundled audio', () {
    /// Every `.m4a` actually in the assets directory.
    final files = Directory(VoiceLine.assetDirectory)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList();

    String basename(File file) =>
        file.path.split(RegExp(r'[/\\]')).last.replaceAll('.m4a', '');

    test('every line has a file', () {
      final present = files.map(basename).toSet();
      final missing = VoiceLine.values
          .where((line) => !present.contains(line.id))
          .map((line) => line.id)
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'these lines would play as silence on a screen whose user cannot '
            'read it: $missing. Generate them with '
            'supabase/tools/generate-voice-lines.ts --only=${missing.join(",")}',
      );
    });

    test('every file belongs to a line', () {
      final orphans = files
          .map(basename)
          .where((id) => VoiceLine.byId(id) == null)
          .toList();
      expect(
        orphans,
        isEmpty,
        reason:
            'these files ship in the APK and nothing can ever play them — a '
            'renamed line leaves its old audio behind: $orphans',
      );
    });

    test('no file is silence', () {
      // A session can answer with a transcript and no audio: on 2026-11-14
      // `docs_delete_done` came back verbatim and 257 bytes — a container
      // header with nothing in it, which existence alone would have accepted.
      // Every real line here is at least 1.5 s, i.e. several KB.
      final empty = files
          .where((f) => f.lengthSync() < 2048)
          .map((f) => '${basename(f)} (${f.lengthSync()} bytes)')
          .toList();
      expect(
        empty,
        isEmpty,
        reason: 'these files have no audio in them: $empty',
      );
    });

    test('the bundle stays inside its budget', () {
      // D5 sized the feature at ~360 KB. Not a hard limit, but a line that
      // doubles in length should be noticed here rather than in an APK report.
      final total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
      expect(
        total,
        lessThan(400 * 1024),
        reason:
            '${(total / 1024).round()} KB of fixed lines is past D5\'s '
            '~360 KB budget',
      );
    });

    test('the directory is declared in pubspec', () {
      // A file in the repo that pubspec does not declare is not in the APK,
      // and fails at runtime exactly like a missing one — but passes every
      // assertion above.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('- ${VoiceLine.assetDirectory}/'),
        reason:
            'assets/voice_lines/ is not bundled, so every fixed line is '
            'missing at runtime',
      );
    });
  });
}
