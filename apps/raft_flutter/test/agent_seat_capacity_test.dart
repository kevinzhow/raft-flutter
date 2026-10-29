import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/members_settings/runtime_forms.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, this.billing);
  final Map<String, dynamic> billing;
  final posts = <String>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/billing/subscription') return billing;
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'computer',
            'name': 'Fixture',
            'status': 'online',
            'runtimes': ['codex'],
          },
        ],
      };
    }
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
        ],
      };
    }
    if (path.endsWith('/runtime-forms/v2/codex')) {
      return msRuntimeForms['forms']['codex'];
    }
    if (path.endsWith('/runtime-forms/v2/codex/option-sources/model')) {
      return {
        ...(msRuntimeForms['forms']['codex']['optionSources']['model'] as Map),
        'options': [
          {'value': 'gpt-5', 'label': 'GPT-5'},
        ],
        'defaultValue': 'gpt-5',
        'customValueAllowed': true,
      };
    }
    throw RaftApiException('Fixture route absent', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add(path);
    return {'id': 'created', 'name': data['name']};
  }
}

void main() {
  for (final (used, limit, agents, maxAgents, allowed) in [
    (1.8, 2, 8, -1, true),
    (1 + 9 * .1, 2, 9, -1, true),
    (2.0, 2, 10, -1, false),
    (1.91, 2, 9, -1, false),
    (2.0, -1, 10, -1, true),
    (1.8, 2, 8, 8, false),
    (1.8, 2, 8, 9, true),
  ]) {
    testWidgets(
      'create Agent at $used/$limit seats and $agents/$maxAgents agents',
      (tester) async {
        final client = _Client()..user = RaftRecord({'id': 'alice'});
        client.selectServer('s');
        final workspace = _Workspace(client, {
          'displayName': 'Pro',
          'capacity': {'maxAgents': maxAgents, 'maxUniversalSeats': limit},
          'usage': {'humans': 1, 'agents': agents, 'universalSeats': used},
        })..server = RaftRecord({'id': 's', 'role': 'owner'});
        addTearDown(() async {
          workspace.dispose();
          await client.stream.close();
          await client.dispose();
        });
        await tester.binding.setSurfaceSize(const Size(390, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showManagedAgentForm(
                    context,
                    workspace,
                    initialName: 'Seat-check',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('limit reached ('),
          allowed ? findsNothing : findsOneWidget,
        );
        // The dialog title and its submit button share the label.
        await tester.tap(find.text('Create Agent').last);
        await tester.pumpAndSettle();
        expect(workspace.posts, allowed ? ['/agents'] : isEmpty);
        expect(
          find.text('Create Agent'),
          allowed ? findsNothing : findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
