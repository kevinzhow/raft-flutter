import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No-wait-UI guard (Kevin, 2026-10-12: "我们有好多地方都在等").
///
/// A surface must never wait for the network before it appears. This scan
/// fails when one function awaits a network read at its own block level
/// (`await ...client.get(...)`, `await w.query(...)`, a directory or channel
/// refresh) and LATER, in the same function, opens a surface
/// (`showRaftModal`, `showDialog`, `Navigator.push`, ...). Open the surface
/// first, from the local copy (workspace entity directory, page snapshot,
/// cached roster), and refresh in the background; only a surface that has no
/// local data may show its skeleton.
///
/// What may stay: an ACTION that must complete before the next surface (a
/// create/save/mutation whose result the next dialog shows), or a call the
/// user already confirmed. Each such function needs an allowlist entry with a
/// reason; entries that no longer match must be removed.
final _opener = RegExp(
  r'\b(showRaft(?:Modal|Dialog|OverflowSheet|AgentModal|MessageContextMenu)|'
  r'showDialog|showModalBottomSheet|showGeneralDialog|showMenu|'
  r'RaftConfirmDialog\.show)\b\s*[(<]|'
  r'Navigator\.(?:of\([^)]*\)\s*\.)?push\w*\(|\bnavigator\.push\w*\(',
);
final _networkAwait = RegExp(
  r'\bawait\b[^;]*?(?:'
  r'\bclient\.(?:get|post|put|patch|delete|request)\(|'
  r'\.query\(|\.command\(|'
  r'\bentityDirectory\.(?:refresh|preload|ensure)\(|'
  r'\.refreshChannels\(|\.loadSidebar\(|'
  r'\b_?(?:load|fetch|reload|refresh)[A-Z]?\w*\()',
);

final _localHint = RegExp(
  r'loaded|cached|cache|snapshot|settled|known|ready|restor|directory|'
  r'isEmpty|== null|local|!\w*\.?(?:has|contains)',
  caseSensitive: false,
);

/// 'path:function' -> why waiting is correct there.
const _allow = <String, String>{
  'lib/features/message_presentation.dart:open':
      'The awaited `/messages/context` read is in the `raft://thread` branch, '
      'which returns after jumping to the resolved message; the dialogs below '
      'belong to other link kinds. A thread not held locally has no known '
      'target channel to open until it is resolved.',
};

class _Hit {
  _Hit(this.file, this.function, this.awaitLine, this.openLine);
  final String file, function;
  final int awaitLine, openLine;
  String get key => '$file:$function';
  @override
  String toString() =>
      '$file:$awaitLine awaits the network before opening a surface at '
      '$openLine (in $function)';
}

/// True when the await at [k] runs on every call of the function: at block
/// level or inside `try`/`catch`/`finally`. An await inside a closure (a
/// builder, `onSubmit`) runs later. One inside an `else` branch, a conditional
/// expression, or an `if` whose condition asks about local data (`loaded`,
/// `cached`, `snapshot`, `== null`, ...) is the "only when there is no local
/// copy" fetch the fix pattern uses, so none of those gate the surface.
bool _gatesFunction(List<String> lines, int start, int k, int bodyIndent) {
  final own = lines[k].trim();
  if (own.startsWith('?') || own.startsWith(':')) return false;
  var current = _indent(lines[k]);
  for (var j = k - 1; j > start && current > bodyIndent; j--) {
    final line = lines[j];
    if (line.trim().isEmpty || _indent(line) >= current) continue;
    current = _indent(line);
    final text = line.trim();
    final transparent = RegExp(
      r'^(try\b|\}\s*catch\b|\}\s*finally\b|on\s+\w+.*\bcatch\b|'
      r'(if|for|while|switch)\s*\(|case\b)',
    );
    if (!transparent.hasMatch(text)) return false;
    if (text.startsWith('if') && _localHint.hasMatch(text)) return false;
  }
  return true;
}

int _indent(String line) => line.length - line.trimLeft().length;

List<_Hit> _scan(String file, List<String> lines) {
  final hits = <_Hit>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (trimmed.startsWith('//') || !_opener.hasMatch(line)) continue;
    // Enclosing declaration: the nearest earlier line at indent 0 or 2.
    var start = i;
    while (start > 0) {
      final candidate = lines[start];
      final ind = _indent(candidate);
      if (candidate.trim().isNotEmpty &&
          (ind == 0 || ind == 2) &&
          !candidate.trim().startsWith('//') &&
          !candidate.trim().startsWith('@') &&
          !candidate.trim().startsWith('}') &&
          !candidate.trim().startsWith(')') &&
          !candidate.trim().startsWith(']')) {
        break;
      }
      start--;
    }
    final header = lines[start];
    final bodyIndent = _indent(header) + 2;
    final name =
        RegExp(r'(\w+)\s*(?:<[^>]*>)?\(').firstMatch(header)?.group(1) ??
        header.trim();
    for (var k = start + 1; k < i; k++) {
      if (!_networkAwait.hasMatch(lines[k]) ||
          !_gatesFunction(lines, start, k, bodyIndent)) {
        continue;
      }
      hits.add(_Hit(file, name, k + 1, i + 1));
      break;
    }
  }
  return hits;
}

void main() {
  test('no function awaits the network before opening a surface', () {
    final hits = <_Hit>[];
    final root = Directory('lib');
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('preview')) continue;
      hits.addAll(_scan(entity.path, entity.readAsLinesSync()));
    }
    final unlisted = [
      for (final hit in hits)
        if (!_allow.containsKey(hit.key)) hit,
    ];
    expect(
      unlisted,
      isEmpty,
      reason:
          'Open the surface from local data first and refresh in the '
          'background, or add an allowlist entry with a reason.',
    );
    final stale = [
      for (final key in _allow.keys)
        if (!hits.any((hit) => hit.key == key)) key,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'Remove allowlist entries that no longer match.',
    );
  });

  group('the scan itself', () {
    test('flags a read awaited before showRaftModal', () {
      final hits = _scan(
        'a.dart',
        '''
class A {
  static Future<void> show(W w) async {
    final rows = await w.query('/agents');
    await showRaftModal<void>(builder: (_) => D(rows));
  }
}
'''
            .split('\n'),
      );
      expect(hits.single.function, 'show');
    });
    test('ignores awaits inside the surface builder and after it', () {
      final hits = _scan(
        'a.dart',
        '''
class A {
  Future<void> open(W w) async {
    await showRaftModal<void>(
      builder: (_) => D(onSubmit: () async {
        await w.command('POST', '/x');
      }),
    );
    await w.refreshChannels();
  }
}
'''
            .split('\n'),
      );
      expect(hits, isEmpty);
    });
  });
}
