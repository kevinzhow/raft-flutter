import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

// A 1x1 transparent PNG.
final _png = base64Encode(const [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49, //
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0d,
  0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
  0x60, 0x82,
]);

Map<String, dynamic> _file(
  String path, {
  String? content,
  bool binary = false,
  String? encoding,
  String? mimeType,
  int size = 2048,
}) => {
  'path': path,
  'content': content,
  'binary': binary,
  'encoding': ?encoding,
  'mimeType': ?mimeType,
  'size': size,
  'modifiedAt': '2026-10-20T09:30:00.000Z',
};

void main() {
  final routes = <String, Object? Function()>{
    '/agents/a/workspace-files': () => {
      'files': [
        for (final name in ['notes.md', 'todo.txt', 'logo.png', 'core.bin'])
          {'name': name, 'path': name, 'isDirectory': false, 'isHidden': false},
      ],
    },
  };
  final files = {
    'notes.md': _file('notes.md', content: '# Plan\n\nShip **it** today.'),
    'todo.txt': _file('todo.txt', content: 'plain text', size: 10),
    'logo.png': _file(
      'logo.png',
      content: _png,
      binary: true,
      encoding: 'base64',
      mimeType: 'image/png',
      size: 70,
    ),
    'core.bin': _file(
      'core.bin',
      content: null,
      binary: true,
      size: 3 * 1024 * 1024,
    ),
  };

  Future<void> open(WidgetTester tester, String name) async {
    await pumpAgentPanel(
      tester,
      routes: routes,
      readFile: (path) => files[path],
      tab: AgentDetailTab.workspace,
      size: const Size(1200, 800),
    );
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('a Markdown file opens rendered, with a Raw toggle', (
    tester,
  ) async {
    await open(tester, 'notes.md');
    expect(
      find.byKey(const ValueKey('workspace-file-markdown')),
      findsOneWidget,
    );
    expect(find.textContaining('# Plan'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('workspace-file-view-raw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-file-markdown')), findsNothing);
    expect(find.textContaining('# Plan'), findsOneWidget);
    // The mode survives opening another file and coming back.
    await tester.tap(find.byKey(const ValueKey('workspace-file-view-preview')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-file-markdown')),
      findsOneWidget,
    );
  });

  testWidgets('a text file has no toggle and shows its source', (tester) async {
    await open(tester, 'todo.txt');
    expect(find.text('plain text'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-file-view-mode')),
      findsNothing,
    );
  });

  testWidgets('an image the server sent base64 shows as a picture', (
    tester,
  ) async {
    await open(tester, 'logo.png');
    expect(find.byKey(const ValueKey('workspace-file-image')), findsOneWidget);
    expect(find.text('Binary file — cannot display'), findsNothing);
  });

  testWidgets('any other binary file says it cannot be displayed', (
    tester,
  ) async {
    await open(tester, 'core.bin');
    expect(find.text('Binary file — cannot display'), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-file-image')), findsNothing);
  });

  testWidgets('the bottom bar shows the size and the modification time', (
    tester,
  ) async {
    await open(tester, 'core.bin');
    expect(find.text('3.0 MB'), findsOneWidget);
    expect(find.textContaining('Oct 20'), findsOneWidget);
  });

  test('workspaceFileSize follows Web formatSize', () {
    expect(workspaceFileSize(0), '0 B');
    expect(workspaceFileSize(1023), '1023 B');
    expect(workspaceFileSize(1536), '1.5 KB');
    expect(workspaceFileSize(5 * 1024 * 1024), '5.0 MB');
  });
}
