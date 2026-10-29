// Small cloud-agent labels: the sidebar's "cloud" group (Web Sidebar
// `layout.sidebar.cloudAgentGroupLabel`) and the sender line's "Cloud agent ·
// Free for a limited time" (Web MessageItem `message.agentModel.hosted`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/message_agent_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'self'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents') {
      return [
        {'id': 'a', 'name': 'On-Mac', 'machineId': 'first'},
        {
          'id': 'b',
          'name': 'Cloud-One',
          'external': true,
          'hostedRuntime': {'provider': 'antiproton', 'state': 'active'},
        },
        {'id': 'c', 'name': 'Loose-One'},
        {
          'id': 'd',
          'name': 'Cloud-Two',
          'external': true,
          'hostedRuntime': {'provider': 'antiproton', 'state': 'failed'},
        },
      ];
    }
    if (path.endsWith('/members')) return [];
    if (path.endsWith('/machines')) {
      return [
        {'id': 'first', 'name': 'First computer'},
      ];
    }
    return [];
  }
}

void main() {
  testWidgets('a cloud agent has its own group, not "no computer"', (t) async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: DesktopDirectoryView(controller: w, onSelected: (_) {}),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final groups = t
        .widgetList<RaftSidebarMachineGroup>(
          find.byType(RaftSidebarMachineGroup),
        )
        .toList();
    expect(groups.map((g) => g.name), [
      'First computer',
      'cloud',
      'No computer',
    ]);
    expect(groups.map((g) => g.count), [1, 2, 1]);
    expect(
      find.byKey(const ValueKey('directory-machine-group-__cloud__')),
      findsOneWidget,
    );
  });

  group('sender model line', () {
    const scope = (
      origin: 'https://fixture.invalid',
      principal: 'self',
      server: 's',
      authorityRevision: 0,
    );

    Future<String?> label(
      WidgetTester t,
      AgentPresentationIdentity identity, {
      Locale locale = const Locale('en'),
    }) async {
      String? out;
      await t.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              out = messageAgentModelLabel(
                context,
                scope: scope,
                identity: identity,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return out;
    }

    testWidgets('a cloud agent reads Cloud agent · Free for a limited time', (
      t,
    ) async {
      final cloud = AgentPresentationIdentity(
        id: 'b',
        status: 'active',
        runtime: 'external',
        model: 'external',
        external: true,
        hosted: true,
      );
      expect(await label(t, cloud), 'Cloud agent · Free for a limited time');
      expect(
        await label(t, cloud, locale: const Locale('zh')),
        '云端 agent · 限时免费',
      );
    });

    testWidgets('any other agent keeps its model name', (t) async {
      final local = AgentPresentationIdentity(
        id: 'a',
        status: 'active',
        runtime: 'codex',
        model: 'gpt-5',
      );
      expect(await label(t, local), isNot(contains('Cloud agent')));
      final selfRun = AgentPresentationIdentity(
        id: 'e',
        status: 'active',
        runtime: 'external',
        model: 'external',
        external: true,
      );
      expect(await label(t, selfRun), isNot(contains('Cloud agent')));
    });
  });
}
