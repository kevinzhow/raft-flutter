import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

const _link = 'Link — not opened in the workspace viewer';

/// Web v1.24 AgentWorkspace (components/agent/AgentWorkspace.tsx): a symlink
/// row is shown but never opened, `computer_access_revoked` is a final load
/// error (no Retry, no path bar), and the Markdown toggle reads Preview, Raw.
void main() {
  Map<String, Object? Function()> routes({String? failWith}) => {
    '/agents/a/workspace-files': () {
      if (failWith != null) {
        throw RaftApiException.response(
          'raw server text',
          status: 409,
          body: {'error': 'raw server text', 'code': failWith},
        );
      }
      return {
        'files': [
          {
            'name': 'current',
            'path': 'current',
            'isDirectory': false,
            'isHidden': false,
            'isSymlink': true,
          },
          {
            'name': 'notes.md',
            'path': 'notes.md',
            'isDirectory': false,
            'isHidden': false,
          },
        ],
      };
    },
  };

  for (final (label, size, platform) in [
    ('fold 856x944', const Size(856, 944), TargetPlatform.android),
    ('fold 944x856', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop 390x844', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('a symlink row is shown and never opened ($label)', (
      tester,
    ) async {
      final reads = <String>[];
      await pumpAgentPanel(
        tester,
        routes: routes(),
        readFile: (path) {
          reads.add(path);
          return {
            'path': path,
            'content': '# Plan',
            'binary': false,
            'size': 6,
          };
        },
        tab: AgentDetailTab.workspace,
        size: size,
        platform: platform,
      );
      expect(find.text('current'), findsOneWidget);
      expect(find.bySemanticsLabel('current, $_link'), findsOneWidget);
      await tester.tap(find.text('current'));
      await tester.pumpAndSettle();
      // Nothing opened: no read, no file pane (its path stays out of the tree).
      expect(reads, isEmpty);
      // The tree is still the one pane showing (a file would replace it on a
      // narrow window).
      expect(find.text('notes.md'), findsOneWidget);
      // A file next to it still opens.
      await tester.tap(find.text('notes.md'));
      await tester.pumpAndSettle();
      expect(reads, ['notes.md']);
    });
  }

  testWidgets('computer_access_revoked is final: no Retry, no path bar', (
    tester,
  ) async {
    final (w, _) = await pumpAgentPanel(
      tester,
      routes: routes(failWith: 'computer_access_revoked'),
      tab: AgentDetailTab.workspace,
    );
    expect(
      find.text(
        'Computer access revoked: move the agent to another computer (re-attaching adds a new one)',
      ),
      findsOneWidget,
    );
    expect(find.text('raw server text'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Copy path'), findsNothing);
    expect(
      w.queries.where((q) => q.$1 == '/agents/a/workspace-files'),
      hasLength(1),
    );
  });

  testWidgets('an offline Computer still offers Retry (not final)', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      routes: routes(failWith: 'machine_offline'),
      tab: AgentDetailTab.workspace,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the Markdown toggle lists Preview before Raw', (tester) async {
    await pumpAgentPanel(
      tester,
      routes: routes(),
      readFile: (path) => {
        'path': path,
        'content': '# Plan',
        'binary': false,
        'size': 6,
      },
      tab: AgentDetailTab.workspace,
      size: const Size(1200, 800),
    );
    await tester.tap(find.text('notes.md'));
    await tester.pumpAndSettle();
    final preview = tester.getTopLeft(
      find.byKey(const ValueKey('workspace-file-view-preview')),
    );
    final raw = tester.getTopLeft(
      find.byKey(const ValueKey('workspace-file-view-raw')),
    );
    expect(preview.dx, lessThan(raw.dx));
  });
}
