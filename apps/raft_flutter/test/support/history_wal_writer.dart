import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Child-only fixture. The parent kills it after the uncommitted write.
Future<void> main(List<String> arguments) async {
  final expected = jsonDecode(arguments[1]) as Map<String, dynamic>;
  final diagnostics = sqlite3.openInMemory();
  late final List<String> options;
  try {
    options = [
      for (final row in diagnostics.select('PRAGMA compile_options'))
        row.values.single as String,
    ]..sort();
  } finally {
    diagnostics.close();
  }
  if (sqlite3.version.sourceId != expected['sourceId'] ||
      jsonEncode(options) != jsonEncode(expected['options'])) {
    throw StateError('SQLite library differs from the test process.');
  }
  final database = sqlite3.open(arguments[0]);
  try {
    final mode = database.select('PRAGMA journal_mode').single.values.single;
    if (mode != 'wal') {
      throw StateError(
        'The crash fixture must already use WAL; got $mode at ${arguments[0]}.',
      );
    }
    database.execute('BEGIN IMMEDIATE');
    final rows = database.select('SELECT payload FROM raft_history_rows');
    if (rows.length != 1) throw StateError('Expected one committed body.');
    final payload =
        jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>;
    payload['content'] = 'Uncommitted';
    database.execute('UPDATE raft_history_rows SET payload=?', [
      jsonEncode(payload),
    ]);
    final changed = database.select('SELECT payload FROM raft_history_rows');
    if (jsonDecode(changed.single['payload'] as String)['content'] !=
        'Uncommitted') {
      throw StateError('The writer did not mutate its transaction.');
    }
    stdout.writeln('MUTATED');
    await stdout.flush();
    // Keep the process alive with an open transaction until the parent kills
    // it. EOF is only a cleanup fallback and never the successful test path.
    await stdin.drain<void>();
  } finally {
    database.close();
  }
}
