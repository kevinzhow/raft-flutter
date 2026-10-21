// The server's shared model-label catalog (Web modelLabelCatalogStore.ts):
// a name the server's Computers reported beats the bundled table, and a
// model the server names itself is never shown as a bare id.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/model_label_catalog.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
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
  final reads = <String>[];
  Object? answer;
  Object? failure;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/model-label-catalog')) {
      reads.add(path);
      if (failure != null) throw failure!;
      return answer;
    }
    return [];
  }
}

Map<String, dynamic> catalog(String label) => {
  'machines': {
    'm1': {
      'runtimes': {
        'codex': {
          'updatedAt': '2026-10-21T00:00:00Z',
          'models': [
            {'id': 'gpt-custom', 'label': label},
          ],
        },
      },
    },
  },
};

void main() {
  late _Client client;
  late WorkspaceController w;
  late DateTime now;
  late ModelLabelCatalogStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client()..answer = catalog('GPT Custom');
    now = DateTime.utc(2026, 10, 21, 8);
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
    store = ModelLabelCatalogStore(w, clock: () => now);
  });
  tearDown(() async {
    store.dispose();
    w.services.entityDirectory.dispose();
    w.dispose();
    await client.stream.close();
    await client.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a custom model reads its server name, not the bare id', () async {
    expect(store.label('m1', 'codex', 'gpt-custom'), isNull);
    store.load();
    await settle();
    expect(client.reads, ['/servers/s/model-label-catalog']);
    expect(store.label('m1', 'codex', 'gpt-custom'), 'GPT Custom');
    expect(store.label('m2', 'codex', 'gpt-custom'), isNull);
    expect(store.label('m1', 'claude', 'gpt-custom'), isNull);
  });

  test('the presentation layer finds the accepted catalog by scope', () async {
    final scope = (
      origin: w.client.origin,
      principal: 'alice',
      server: 's',
      authorityRevision: w.client.generation,
    );
    const agent = AgentPresentationIdentity(
      id: 'a',
      status: 'online',
      runtime: 'codex',
      machineId: 'm1',
      model: 'gpt-custom',
    );
    expect(
      agentPresentationModelLabel(scope: scope, identity: agent),
      'gpt-custom',
    );
    store.load();
    await settle();
    expect(
      agentPresentationModelLabel(scope: scope, identity: agent),
      'GPT Custom',
    );
    // Another session's scope never sees it.
    expect(
      agentPresentationModelLabel(
        scope: (
          origin: scope.origin,
          principal: 'bob',
          server: 's',
          authorityRevision: scope.authorityRevision,
        ),
        identity: agent,
      ),
      'gpt-custom',
    );
  });

  test('display falls back to the bundled name, then the id', () async {
    store.load();
    await settle();
    // `modelDisplayLabel` reads the session's own store.
    final own = ModelLabelCatalogStore.of(w)..load();
    await settle();
    expect(
      modelDisplayLabel(
        w,
        machineId: 'm1',
        runtime: 'codex',
        model: 'gpt-custom',
      ),
      'GPT Custom',
    );
    expect(
      modelDisplayLabel(
        w,
        machineId: 'm9',
        runtime: 'codex',
        model: 'unknown-x',
      ),
      'unknown-x',
    );
    expect(own, same(ModelLabelCatalogStore.of(w)));
  });

  test(
    'a loaded catalog is not read again inside the window; force skips it',
    () async {
      store.load();
      await settle();
      now = now.add(const Duration(minutes: 4));
      store.load();
      await settle();
      expect(client.reads, hasLength(1));
      now = now.add(const Duration(minutes: 2));
      store.load();
      await settle();
      expect(client.reads, hasLength(2));
      store.load(force: true);
      await settle();
      expect(client.reads, hasLength(3));
    },
  );

  test(
    'a failed read backs off 60 seconds and keeps a previous good catalog',
    () async {
      client.failure = StateError('offline');
      store.load();
      await settle();
      now = now.add(const Duration(seconds: 30));
      store.load();
      await settle();
      expect(client.reads, hasLength(1), reason: 'still backing off');
      client.failure = null;
      now = now.add(const Duration(seconds: 31));
      store.load();
      await settle();
      expect(client.reads, hasLength(2));
      expect(store.label('m1', 'codex', 'gpt-custom'), 'GPT Custom');
      // A later failure does not clear it.
      client.failure = StateError('offline');
      store.load(force: true);
      await settle();
      expect(store.label('m1', 'codex', 'gpt-custom'), 'GPT Custom');
    },
  );

  test('a malformed payload never replaces a good catalog', () async {
    store.load();
    await settle();
    client.answer = {'machines': 'nope'};
    store.load(force: true);
    await settle();
    expect(store.label('m1', 'codex', 'gpt-custom'), 'GPT Custom');
    expect(parseModelLabelCatalog([]), isNull);
    expect(
      parseModelLabelCatalog({
        'machines': {'m': {}},
      }),
      isNull,
    );
  });

  test('listeners hear a newly accepted catalog', () async {
    var heard = 0;
    store.addListener(() => heard++);
    store.load();
    await settle();
    expect(heard, 1);
  });
}
