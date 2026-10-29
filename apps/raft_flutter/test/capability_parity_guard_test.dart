import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Capability-parity guard.
///
/// `docs/capability-parity.json` lists every Web client-to-server call (as
/// "METHOD /path/:id", plus "RAW file" and "SOCKET emit event") and the
/// client-side capabilities, with a status for the Flutter app. Pixel parity,
/// field parity and the page inventory never compared what a user can DO; this
/// does.
///
/// (a) Every covered / partial entry names Flutter locations (file + needle)
///     that must still exist, so a refactor cannot silently remove the entry
///     point the document claims. Other statuses must carry their reasons.
/// (b) With `RAFT_WEB_SOURCE=/path/to/raft-source` the Web endpoints are
///     extracted again (tool/capability_parity.py) and every key must be in
///     the JSON, so a new Web capability cannot be missed without a decision.
///     Without the variable (b) is skipped.
///
/// After deciding a new Web capability, add it to docs/capability-parity.json
/// (status, Flutter location or the reason) and regenerate
/// docs/capability-parity.md with `python3 tool/capability_parity_report.py`.
const _statuses = {'covered', 'partial', 'missing', 'na'};
const _sizes = {'S', 'M', 'L'};

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/packages/raft_ui').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repository root not found');
    dir = parent;
  }
  return dir;
}

List<Map<String, dynamic>> _entries(Directory root) {
  final file = File('${root.path}/docs/capability-parity.json');
  if (!file.existsSync()) throw StateError('docs/capability-parity.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final e in decoded['entries'] as List<dynamic>)
      Map<String, dynamic>.from(e as Map),
  ];
}

String _s(Map<String, dynamic> e, String key) => (e[key] as String?) ?? '';

void main() {
  final root = _repoRoot();
  final entries = _entries(root);

  test('every entry is well formed and carries its reasons', () {
    final problems = <String>[];
    final seen = <String>{};
    for (final e in entries) {
      final id = _s(e, 'id');
      final status = _s(e, 'status');
      if (id.isEmpty) problems.add('entry without id: $e');
      if (!seen.add(id)) problems.add('duplicate id: $id');
      if (!_statuses.contains(status)) {
        problems.add('$id: unknown status "$status"');
      }
      if (_s(e, 'capability').isEmpty) problems.add('$id: capability empty');
      if (_s(e, 'webEntry').isEmpty) problems.add('$id: webEntry empty');
      if (status == 'na' && _s(e, 'justification').isEmpty) {
        problems.add('$id: na without justification');
      }
      if (status == 'partial' && _s(e, 'justification').isEmpty) {
        problems.add('$id: partial without a note on what differs');
      }
      if (status == 'missing' || status == 'partial') {
        if (_s(e, 'impact').isEmpty) problems.add('$id: gap without impact');
        if (!_sizes.contains(_s(e, 'size'))) {
          problems.add('$id: gap without size S/M/L');
        }
      }
      if (status == 'covered' || status == 'partial') {
        if (((e['flutterRefs'] as List<dynamic>?) ?? const []).isEmpty) {
          problems.add('$id: $status without flutterRefs');
        }
        if (_s(e, 'flutterEntry').isEmpty) {
          problems.add('$id: $status without flutterEntry');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every covered or partial entry still points at existing Flutter code',
      () {
    final problems = <String>[];
    final cache = <String, String?>{};
    for (final e in entries) {
      final status = _s(e, 'status');
      if (status != 'covered' && status != 'partial') continue;
      for (final ref in (e['flutterRefs'] as List<dynamic>? ?? const [])) {
        final map = Map<String, dynamic>.from(ref as Map);
        final path = _s(map, 'file');
        final needle = _s(map, 'needle');
        final text = cache.putIfAbsent(path, () {
          final f = File('${root.path}/$path');
          return f.existsSync() ? f.readAsStringSync() : null;
        });
        if (text == null) {
          problems.add('${e['id']}: $path no longer exists');
        } else if (needle.isEmpty || !text.contains(needle)) {
          problems.add('${e['id']}: "$needle" not found in $path');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  final webSource = Platform.environment['RAFT_WEB_SOURCE'];
  test(
    'every Web endpoint is recorded in docs/capability-parity.json',
    () {
      final result = Process.runSync('python3', [
        '${root.path}/tool/capability_parity.py',
        'keys',
        webSource!,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final webKeys = (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toSet();
      final recorded = {
        for (final e in entries)
          if (e['kind'] == 'endpoint') _s(e, 'id'),
      };
      final unrecorded = (webKeys.difference(recorded).toList()..sort());
      final stale = (recorded.difference(webKeys).toList()..sort());
      if (stale.isNotEmpty) {
        // Informational: Web dropped or renamed it; refresh the document.
        // ignore: avoid_print
        print('capability-parity: recorded but no longer in Web:\n'
            '${stale.join('\n')}');
      }
      expect(
        unrecorded,
        isEmpty,
        reason: 'Web has capabilities that docs/capability-parity.json does '
            'not record. Decide each one (covered / partial / missing / na) '
            'and add it:\n${unrecorded.join('\n')}',
      );
    },
    skip: webSource == null || webSource.isEmpty
        ? 'set RAFT_WEB_SOURCE=/path/to/raft-source to compare with Web'
        : false,
  );
}
