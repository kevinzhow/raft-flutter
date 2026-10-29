// The session's model-label store is disposed with its workspace, so its
// accepted catalog never outlives the session in the static
// AgentModelLabelRegistry (which would keep the workspace reachable and let a
// later session with an equal scope read it).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/model_label_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (!path.endsWith('/model-label-catalog')) return [];
    return {
      'machines': {
        'm1': {
          'runtimes': {
            'codex': {
              'models': [
                {'id': 'gpt-custom', 'label': 'GPT Custom'},
              ],
            },
          },
        },
      },
    };
  }
}

const _agent = AgentPresentationIdentity(
  id: 'a',
  status: 'online',
  runtime: 'codex',
  machineId: 'm1',
  model: 'gpt-custom',
);

void main() {
  late _Client client;
  late WorkspaceController w;
  // The session's scope while it was live: a later session can be equal.
  late AgentPresentationScope liveScope;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
    liveScope = (
      origin: client.origin,
      principal: 'alice',
      server: 's',
      authorityRevision: client.generation,
    );
  });
  tearDown(() async {
    await client.stream.close();
    await client.dispose();
  });

  String? shown() =>
      agentPresentationModelLabel(scope: liveScope, identity: _agent);

  test('disposing the workspace forgets the session store catalog', () async {
    ModelLabelCatalogStore.of(w).load();
    await Future<void>.delayed(Duration.zero);
    expect(shown(), 'GPT Custom');
    w.services.entityDirectory.dispose();
    w.dispose();
    // A later session with an equal scope no longer reads the old catalog.
    expect(shown(), 'gpt-custom');
  });

  test('the store of a disposed session is inert', () async {
    final store = ModelLabelCatalogStore.of(w);
    w.services.entityDirectory.dispose();
    w.dispose();
    store.load();
    await Future<void>.delayed(Duration.zero);
    expect(shown(), 'gpt-custom');
    store.dispose();
  });
}
