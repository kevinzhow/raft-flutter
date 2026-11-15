// Web v1.24 useExternalAgentCredentials.ts: the credential made on the
// external agent's page is named PAGE_CREDENTIAL_NAME ("Created on this
// page"), so a later "Create new credential" replaces only it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _agent = <String, dynamic>{
  'id': 'ext-1',
  'name': 'Hermes-Bridge',
  'displayName': 'Hermes Bridge',
  'status': 'active',
  'runtime': 'external',
  'model': 'external',
  'external': true,
  'creatorType': 'user',
  'creatorId': 'alice',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final posts = <dynamic>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (path == '/agents') return [_agent];
    if (path == '/agents/ext-1') return _agent;
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/agents/ext-1/external-status') {
      return {'setupState': 'credential_minted'};
    }
    if (path == '/agents/ext-1/credentials' && method == 'GET') {
      return {'agentId': 'ext-1', 'credentials': []};
    }
    if (path == '/agents/ext-1/credentials' && method == 'POST') {
      posts.add(data);
      return {
        'agentId': 'ext-1',
        'credentialId': 'cred-new',
        'apiKey': 'sk_agent_0123456789abcdefghijklmnop',
      };
    }
    return [];
  }
}

void main() {
  testWidgets('Create credential names the credential "Created on this page"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Client()..selectServer('s');
    final w = WorkspaceController(c)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: FleetDetail(
            key: UniqueKey(),
            controller: w,
            computers: false,
            initial: _agent,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('external-agent-create-credential')),
    );
    await tester.pumpAndSettle();
    expect(c.posts, [
      {'name': 'Created on this page'},
    ]);
  });
}
