import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('MCP servers: badges, icon actions, tools, recommendations', (
    t,
  ) async {
    var edits = 0, adds = 0;
    await t.pumpWidget(
      _host(
        RaftMcpServersSection(
          onAddServer: () {},
          servers: [
            RaftMcpServerRow(
              id: 'linear',
              name: 'Linear',
              provider: 'linear',
              endpointUrl: 'https://mcp.linear.app/mcp',
              authMode: 'oauth',
              oauthStatus: 'connected',
              tools: const [RaftMcpTool('List issues', 'List issues')],
              actions: [
                RaftMcpAction(
                  glyph: RaftGlyph.pencil,
                  tooltip: 'Edit server',
                  onPressed: () => edits++,
                ),
              ],
            ),
          ],
          recommendations: [
            RaftMcpRecommendation(
              id: 'notion',
              name: 'Notion',
              description: 'Pages',
              onAdd: () => adds++,
            ),
          ],
        ),
      ),
    );
    expect(find.text('Linear'), findsOneWidget);
    expect(find.text('OAuth connected'), findsOneWidget);
    expect(find.text('List issues'), findsNothing);
    await t.tap(find.byKey(const ValueKey('mcp-tools-toggle-linear')));
    await t.pump();
    expect(find.text('List issues'), findsNWidgets(2));
    await t.tap(find.byTooltip('Edit server'));
    await t.tap(find.text('Add'));
    expect((edits, adds), (1, 1));
  });

  testWidgets('MCP servers: empty state offers Add server', (t) async {
    await t.pumpWidget(
      _host(RaftMcpServersSection(servers: const [], onAddServer: () {})),
    );
    expect(find.text('No managed MCP servers yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-empty-add')), findsOneWidget);
  });

  testWidgets('Labs: master gate note and read-only reason', (t) async {
    await t.pumpWidget(
      _host(
        const RaftServerLabsSection(
          status: RaftServerLabsStatus.ready,
          masterEnabled: true,
          labs: [
            RaftServerLab(
              key: 'refs',
              name: 'Refs',
              description: 'Composer refs.',
              checked: false,
              editable: false,
              disabledReason:
                  'Paused, draft, and retired Labs are read-only here.',
            ),
          ],
        ),
      ),
    );
    // The header keeps its sentence case (decision 0002: no all caps).
    expect(find.textContaining('LABS'), findsNothing);
    expect(find.textContaining('Labs'), findsNWidgets(3));
    expect(
      find.text('Only server owners can change the master gate.'),
      findsOneWidget,
    );
    expect(
      find.text('Paused, draft, and retired Labs are read-only here.'),
      findsOneWidget,
    );
  });

  testWidgets('Provider connections: empty box and disabled add', (t) async {
    await t.pumpWidget(
      _host(
        RaftProviderConnectionsFrame(
          rows: const [],
          canAdd: false,
          onAdd: () {},
        ),
      ),
    );
    expect(find.text('No provider connections yet.'), findsOneWidget);
    expect(find.text('Add provider connection'), findsOneWidget);
  });

  testWidgets('Messaging bridges: failure banner replaces the body', (t) async {
    await t.pumpWidget(
      _host(const RaftMessagingBridgesSection(failed: true, child: Text('x'))),
    );
    expect(find.text('Messaging bridges'), findsOneWidget);
    expect(find.text('Raft for Slack'), findsOneWidget);
    expect(find.text('x'), findsNothing);
  });
}
