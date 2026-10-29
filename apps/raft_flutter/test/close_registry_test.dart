import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/close_registry.dart';
import 'support/close_surface.dart';

/// APIs that open a separate closable layer. A file that calls one must be
/// listed in some CloseSurface.files, and that surface then has a harness
/// (close_*_test.dart) proving its × / Back / Escape / scrim / system back at
/// phone, foldable and desktop widths. docs/close-affordances.md is generated
/// from the registry.
final _openers = RegExp(
  r'showRaftModal\(|raftModalRoute\(|showRaftAgentModal\(|showRaftDialog\(|'
  r'showRaftAlertDialog\(|RaftConfirmDialog\.show\(|showDialog[<(]|'
  r'showGeneralDialog[<(]|showModalBottomSheet[<(]|showMenu[<(]|'
  r'showRaftOverflowSheet[<(]|showRaftMessageContextMenu[<(]|'
  r'OverlayEntry\(|OverlayPortalController\(|MaterialPageRoute|'
  r'PageRouteBuilder|DialogRoute|PopupRoute|RaftPanelHeaderBar\(|'
  r'RaftPageHeader\(|RaftDialogCard\(|RaftDialogShell\(|'
  r'RaftAgentDialogCard\(|showRaftForm[<(]|raftFormRoute[<(]|'
  r'showRaftPresented[<(]|raftPresentedRoute[<(]',
);

Iterable<File> _dartFiles(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('_previews.dart') &&
              !f.path.endsWith('.g.dart') &&
              !f.path.contains('/l10n/') &&
              !f.path.contains('/previews'),
        );

String _normalize(String path) =>
    path.startsWith('../../packages/') ? path : path;

void main() {
  final surfaces = allCloseSurfaces;

  test('surface ids are unique and every width has a close or a reason', () {
    final seen = <String>{};
    for (final s in surfaces) {
      expect(seen.add(s.id), isTrue, reason: 'duplicate surface id ${s.id}');
      for (final width in ['phone', 'fold', 'desktop']) {
        if (s.at(width).isEmpty) {
          expect(
            s.none[width],
            isNotNull,
            reason: '${s.id} has no close affordance at $width and no reason',
          );
        }
      }
      expect(
        s.files,
        isNotEmpty,
        reason: '${s.id} lists no source file that builds it',
      );
      expect(s.web.trim(), isNotEmpty, reason: '${s.id} names no Web source');
    }
  });

  test('every listed source file exists', () {
    for (final s in surfaces) {
      for (final f in s.files) {
        expect(
          File(f).existsSync(),
          isTrue,
          reason:
              '${s.id}: $f does not exist (paths are relative to apps/raft_flutter)',
        );
      }
    }
  });

  test('no surface API is called from a file the registry does not list', () {
    final listed = {for (final s in surfaces) ...s.files.map(_normalize)};
    final missing = <String>[];
    for (final root in ['lib', '../../packages/raft_ui/lib/src']) {
      for (final file in _dartFiles(root)) {
        final path = file.path;
        if (listed.contains(path) || closeScanExempt.containsKey(path)) {
          continue;
        }
        if (_openers.hasMatch(file.readAsStringSync())) missing.add(path);
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'These files open a closable layer (dialog, sheet, popup, route, '
          'panel header) but no CloseSurface lists them. Add a CloseSurface '
          'with the Web affordances and a harness (test/close_*_test.dart; '
          'docs/close-affordances.md explains the registry), or add the file '
          'to closeScanExempt with a reason.',
    );
  });

  test('docs/close-affordances.md matches the registry', () {
    final doc = File('../../docs/close-affordances.md');
    expect(doc.existsSync(), isTrue);
    final text = doc.readAsStringSync();
    const start = '<!-- close-table:start -->',
        end = '<!-- close-table:end -->';
    final table = renderCloseTable(surfaces);
    if (Platform.environment['UPDATE_CLOSE_DOCS'] == '1') {
      final head = text.substring(0, text.indexOf(start) + start.length);
      final tail = text.substring(text.indexOf(end));
      doc.writeAsStringSync('$head\n$table\n$tail');
      return;
    }
    final current = text.substring(
      text.indexOf(start) + start.length,
      text.indexOf(end),
    );
    expect(
      current.trim(),
      table.trim(),
      reason:
          'docs/close-affordances.md is stale: run `UPDATE_CLOSE_DOCS=1 '
          'tool/flutter test test/close_registry_test.dart` in apps/raft_flutter',
    );
  });
}

String _set(Set<Affordance> a) {
  if (a.isEmpty) return '-';
  const order = [
    Affordance.x,
    Affordance.back,
    Affordance.esc,
    Affordance.scrim,
    Affordance.systemBack,
    Affordance.drag,
  ];
  const label = {
    Affordance.x: 'x',
    Affordance.back: 'back',
    Affordance.esc: 'esc',
    Affordance.scrim: 'scrim',
    Affordance.systemBack: 'sysback',
    Affordance.drag: 'drag',
  };
  return [
    for (final k in order)
      if (a.contains(k)) label[k],
  ].join(' ');
}

String renderCloseTable(List<CloseSurface> surfaces) {
  final rows = <String>[
    '| surface | kind | phone 390 | foldable 816 | desktop 1280 | Web | status | fix |',
    '|---|---|---|---|---|---|---|---|',
  ];
  for (final s in surfaces) {
    String cell(String width) => s.at(width).isEmpty
        ? '- (${s.none[width] ?? 'none'})'
        : _set(s.at(width));
    String esc(String v) => v.replaceAll('|', '/').replaceAll('\n', ' ');
    rows.add(
      '| `${s.id}` | ${s.kind.name} | ${esc(cell('phone'))} | '
      '${esc(cell('fold'))} | ${esc(cell('desktop'))} | ${esc(s.web)} | '
      '${s.status} | ${esc(s.fix)} |',
    );
  }
  return rows.join('\n');
}
