import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/panel_edge_registry.dart';

/// Static guard for the left-edge rule ("the attached left edge shows
/// everywhere except on a full-width standalone phone page", one place:
/// `RaftPanelEdge`). Same idea as close_registry_test.dart: a new panel cannot
/// skip the rule, and nobody can gate an edge on a width or a "mobile" flag of
/// their own again (that is how the Activity / Search detail lost its divider
/// and how two other surfaces got ad hoc 768 checks).
final _asksRule = RegExp(r'RaftPanelEdge\.|RaftPanelMasterEdge\(');
const _uiLib = '../../packages/raft_ui/lib/src';

Iterable<File> _dartFiles() => [
  for (final root in ['lib', _uiLib])
    ...Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('.g.dart') &&
              !f.path.contains('/l10n/'),
        ),
];

void main() {
  test('surface ids are unique and every listed file exists', () {
    final seen = <String>{};
    for (final s in panelEdgeSurfaces) {
      expect(seen.add(s.id), isTrue, reason: 'duplicate ${s.id}');
      expect(s.web.trim(), isNotEmpty, reason: '${s.id} names no Web source');
      expect(s.files, isNotEmpty, reason: '${s.id} lists no file');
      for (final f in s.files) {
        expect(File(f).existsSync(), isTrue, reason: '${s.id}: $f missing');
      }
    }
  });

  test('every listed file asks RaftPanelEdge', () {
    for (final s in panelEdgeSurfaces) {
      for (final f in s.files) {
        expect(
          _asksRule.hasMatch(File(f).readAsStringSync()),
          isTrue,
          reason: '${s.id}: $f does not use RaftPanelEdge',
        );
      }
    }
  });

  test('no file asks RaftPanelEdge without being registered', () {
    final listed = {for (final s in panelEdgeSurfaces) ...s.files};
    final unregistered = <String>[];
    for (final file in _dartFiles()) {
      if (file.path.endsWith('/panel_edge.dart')) continue;
      if (_asksRule.hasMatch(file.readAsStringSync()) &&
          !listed.contains(file.path)) {
        unregistered.add(file.path);
      }
    }
    expect(
      unregistered,
      isEmpty,
      reason:
          'A surface that draws an attached edge must be a PanelEdgeSurface '
          '(test/support/panel_edge_registry.dart) and have a matrix mount.',
    );
  });

  test('no left border is gated by a width or a mobile flag of its own', () {
    // A `left: BorderSide(` / `Border(left:` whose preceding lines compare a
    // width, ask compactOf / desktopBreakpoint or test a mobile / phone /
    // narrow flag decides its own presentation. Use RaftPanelEdge.
    final gate = RegExp(
      r'desktopBreakpoint|compactOf|\.width\s*[<>]=?\s*\d|\b(mobile|narrow|phone)\b',
    );
    final edge = RegExp(r'left:\s*(const\s+)?BorderSide\(|Border\(\s*left:');
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      if (panelEdgeAllowlist.containsKey(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!edge.hasMatch(lines[i])) continue;
        final context = lines.sublist(i < 8 ? 0 : i - 8, i + 1).join('\n');
        if (gate.hasMatch(context)) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Draw the attached left edge through RaftPanelEdge (raft_ui '
          'panel_edge.dart); do not gate it on a width / mobile flag.',
    );
  });

  test('allowlisted files exist and still need the exception', () {
    for (final entry in panelEdgeAllowlist.entries) {
      expect(File(entry.key).existsSync(), isTrue, reason: entry.key);
      expect(entry.value.trim(), isNotEmpty);
    }
  });
}
