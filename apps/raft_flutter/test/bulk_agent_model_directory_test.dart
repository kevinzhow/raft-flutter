import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

WorkspaceEntityScope scope(String role) => WorkspaceEntityScope(
  origin: 'https://fixture.invalid',
  principal: 'alice',
  serverId: 's',
  generation: 1,
  role: role,
  capabilities: {WorkspaceEntityKind.agents},
);

Map<String, dynamic> agent(String id, String model) => {
  'id': id,
  'name': id,
  'runtime': 'codex',
  'model': model,
  'activity': 'idle',
  'envVars': {'OWN': id},
};

void main() {
  test('command updates merge one agent without reading or replacing unrelated rows', () async {
    var reads = 0;
    final directory = WorkspaceEntityDirectory(
      scope: () => scope('owner'),
      query: (_) async {
        reads++;
        return [agent('a', 'old'), agent('b', 'other')];
      },
    );
    addTearDown(directory.dispose);
    await directory.refresh(WorkspaceEntityKind.agents);
    final untouched = directory.agent('b');
    directory.agentUpdateReceiver()({'id': 'a', 'model': 'new'});
    expect(directory.agent('a')?['model'], 'new');
    expect(directory.agent('a')?['envVars'], {'OWN': 'a'});
    expect(directory.agent('b'), untouched);
    expect(reads, 1);
  });

  test(
    'an old directory response cannot overwrite a newer saved model',
    () async {
      Completer<dynamic>? pending;
      final directory = WorkspaceEntityDirectory(
        scope: () => scope('owner'),
        query: (_) async {
          if (pending == null) return [agent('a', 'old'), agent('b', 'other')];
          return await pending.future;
        },
      );
      addTearDown(directory.dispose);
      await directory.refresh(WorkspaceEntityKind.agents);
      pending = Completer<dynamic>();
      final read = directory.refresh(WorkspaceEntityKind.agents, force: true);
      directory.agentUpdateReceiver()({'id': 'a', 'model': 'new'});
      pending.complete([
        agent('a', 'old'),
        agent('b', 'also-new'),
        agent('c', 'added'),
      ]);
      await read;
      expect(directory.state(WorkspaceEntityKind.agents).error, isNull);
      expect(directory.agent('a')?['model'], 'new');
      expect(directory.agent('b')?['model'], 'also-new');
      expect(directory.agent('c')?['model'], 'added');
    },
  );

  test('leaving and returning to the same authority permanently invalidates an old receiver', () async {
    var current = scope('owner');
    final directory = WorkspaceEntityDirectory(
      scope: () => current,
      query: (_) async => [agent('a', 'old')],
    );
    addTearDown(directory.dispose);
    await directory.refresh(WorkspaceEntityKind.agents);
    final accept = directory.agentUpdateReceiver();
    current = scope('member');
    directory.synchronize();
    current = scope('owner');
    await directory.refresh(WorkspaceEntityKind.agents);
    accept({'id': 'a', 'model': 'private-old-response'});
    expect(directory.agent('a')?['model'], 'old');
  });

  test(
    'a full command response does not roll back newer realtime activity',
    () async {
      final events = StreamController<RaftEvent>.broadcast(sync: true);
      final directory = WorkspaceEntityDirectory(
        scope: () => scope('owner'),
        query: (_) async => [agent('a', 'old')],
        events: events.stream,
      );
      addTearDown(() async {
        directory.dispose();
        await events.close();
      });
      await directory.refresh(WorkspaceEntityKind.agents);
      final accept = directory.agentUpdateReceiver();
      events.add(
        RaftEvent('agent:activity', {
          'agentId': 'a',
          'activity': 'thinking',
          'serverSeq': '2',
        }),
      );
      accept(agent('a', 'new'));
      expect(directory.agent('a')?['model'], 'new');
      expect(directory.agent('a')?['activity'], 'thinking');
    },
  );

  test(
    'an unchanged command still protects an older read, then expires',
    () async {
      final pending = Completer<dynamic>();
      var reads = 0;
      final directory = WorkspaceEntityDirectory(
        scope: () => scope('owner'),
        query: (_) async {
          reads++;
          if (reads == 2) return await pending.future;
          return [agent('a', reads == 1 ? 'new' : 'later')];
        },
      );
      addTearDown(directory.dispose);
      await directory.refresh(WorkspaceEntityKind.agents);
      final read = directory.refresh(WorkspaceEntityKind.agents, force: true);
      directory.agentUpdateReceiver()({'id': 'a', 'model': 'new'});
      pending.complete([agent('a', 'old')]);
      await read;
      expect(directory.state(WorkspaceEntityKind.agents).error, isNull);
      expect(directory.agent('a')?['model'], 'new');
      await directory.refresh(WorkspaceEntityKind.agents, force: true);
      expect(directory.agent('a')?['model'], 'later');
      expect(reads, 3);
    },
  );
}
