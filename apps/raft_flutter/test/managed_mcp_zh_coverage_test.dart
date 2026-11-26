// zh_catalog_test only sees literals handed straight to raftText / raftFormat.
// The managed MCP surfaces also pass copy through local helpers (`_radio`,
// `_plural`) and through widget props that translate inside the widget
// (`RaftAppEditorFootnote`, `RaftAppEditorField.label` / `.hint`,
// `RaftAppEditorSection.status`, `RaftButton.label`, `RaftBadge.label`), so a
// missing Chinese entry there shows the user English. Martin's review found 13
// such strings; this scans every English sentence literal in the MCP sources
// and requires a catalog entry for each.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart' show raftChinese;

/// The package's own files. Each is scanned whole: any UI sentence in them
/// reaches the user through one of the translating widgets above.
const _sources = [
  'lib/data/managed_mcp_apps.dart',
  'lib/features/agent_mcp_access.dart',
  'lib/features/mcp_app_connections.dart',
  'lib/features/mcp_app_editor.dart',
  'lib/features/mcp_app_facts.dart',
  'lib/features/mcp_app_server.dart',
  'lib/features/mcp_connection_fields.dart',
  'lib/features/mcp_web_sign_in.dart',
];

/// Literals that are not user-visible copy: ids, routes, fixture keys and the
/// enum-ish values the wire uses.
bool _isCopy(String text) {
  final value = text.trim();
  if (value.length < 4) return false;
  if (!value.contains(' ') && !value.contains('{')) return false;
  if (value.startsWith('/') || value.contains('://')) return false;
  if (value.startsWith('\$') || value.contains('\${')) return false;
  // A sentence starts with a capital, a digit placeholder or a quote.
  return RegExp(r'^[A-Z{"“]').hasMatch(value);
}

/// String literals in [source], single and double quoted, raw text only.
Iterable<String> _literals(String source) sync* {
  final pattern = RegExp(
    r"'((?:[^'\\\n]|\\.)*)'"
    r'|"((?:[^"\\\n]|\\.)*)"',
    multiLine: true,
  );
  for (final match in pattern.allMatches(source)) {
    final raw = match.group(1) ?? match.group(2) ?? '';
    yield raw
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\$', r'$');
  }
}

void main() {
  test('every English sentence in the MCP surfaces has a Chinese entry', () {
    final missing = <String>[];
    for (final path in _sources) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is listed but missing');
      final source = file
          .readAsStringSync()
          // Comments explain the port; they are never shown.
          .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
      for (final literal in _literals(source)) {
        if (!_isCopy(literal)) continue;
        if (raftChinese.containsKey(literal)) continue;
        missing.add('$path: "$literal"');
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'add these to packages/raft_ui/lib/src/l10n/zh_upstream_1_24_mcp.dart '
          '(Web zh-cn wording where Web has the same English), then rerun '
          'python3 tool/gen_l10n_index.py',
    );
  });
}
