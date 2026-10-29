import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

import 'workspace_entity_directory_test.dart' show agent, scope;

void main() {
  test(
    'presence snapshots keep scalars stable across patches and tombstones',
    () async {
      final directory = WorkspaceEntityDirectory(
        scope: () => scope(),
        query: (_) async => [
          agent,
          {...agent, 'id': 'b'},
        ],
      );
      addTearDown(directory.dispose);
      await directory.refresh(WorkspaceEntityKind.agents);
      final first = directory.agentPresence('a')!;
      final other = directory.agentPresence('b');
      directory.receive(
        RaftEvent('agent:activity', {
          'agentId': 'a',
          'activity': 'thinking',
          'serverSeq': 2,
        }),
      );
      final updated = directory.agentPresence('a')!;
      expect(updated.activity, 'thinking');
      expect(first.activity, 'online');
      expect(directory.agentPresence('b'), same(other));
      directory.receive(
        RaftEvent('agent:activity', {
          'agentId': 'a',
          'activity': 'offline',
          'serverSeq': 1,
        }),
      );
      expect(directory.agentPresence('a'), same(updated));
      directory.receive(RaftEvent('agent:deleted', {'agentId': 'a'}));
      expect(directory.agentPresence('a')?.deleted, isTrue);
      expect(directory.agentPresence('b'), same(other));
    },
  );

  test('a cached sender is fenced on capability and same-generation account changes', () async {
    var authority = scope();
    final directory = WorkspaceEntityDirectory(
      scope: () => authority,
      query: (_) async => [agent],
    );
    addTearDown(directory.dispose);
    await directory.refresh(WorkspaceEntityKind.agents);
    expect(directory.agentPresence('a'), isNotNull);
    authority = scope(capabilities: {});
    expect(directory.agentPresence('a'), isNull);
    authority = scope(principal: 'bob');
    expect(directory.agentPresence('a'), isNull);
    await directory.refresh(WorkspaceEntityKind.agents);
    final restored = directory.agentPresence('a');
    expect(restored?.id, 'a');
    directory.dispose();
    expect(directory.agentPresence('a'), isNull);
  });

  test('revalidation replaces presence scalars without changing borrowed snapshots', () async {
    var row = <String, dynamic>{
      ...agent,
      'hostedRuntime': {
        'credentials': ['private fixture'],
      },
      'lastSeenAt': '2026-10-24T12:00:00Z',
    };
    final directory = WorkspaceEntityDirectory(
      scope: () => scope(),
      query: (_) async => [row],
    );
    addTearDown(directory.dispose);
    await directory.refresh(WorkspaceEntityKind.agents);
    final first = directory.agentPresence('a')!;
    expect(first.hosted, isTrue);
    expect(first.lastSeenAt, DateTime.utc(2026, 10, 24, 12));
    row = {...row, 'description': 'Updated', 'hostedRuntime': null};
    await directory.refresh(WorkspaceEntityKind.agents);
    expect(directory.agentPresence('a')?.description, 'Updated');
    expect(directory.agentPresence('a')?.hosted, isFalse);
    expect(first.hosted, isTrue);
    expect(first.description, isNull);
  });
}
