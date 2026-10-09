import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

const agent = <String, dynamic>{
  'id': 'a',
  'name': 'Source Agent',
  'status': 'active',
  'runtime': 'codex',
  'model': 'gpt-6',
  'activity': 'online',
};
const computer = <String, dynamic>{
  'id': 'c',
  'name': 'Source Computer',
  'status': 'online',
  'userId': 'alice',
};
const member = <String, dynamic>{
  'userId': 'u',
  'name': 'Source Human',
  'role': 'member',
};
WorkspaceEntityScope scope({
  String server = 's',
  String principal = 'alice',
  String role = 'owner',
  int generation = 1,
  Set<WorkspaceEntityKind> capabilities = const {...WorkspaceEntityKind.values},
}) => WorkspaceEntityScope(
  origin: 'https://fixture.test',
  principal: principal,
  serverId: server,
  generation: generation,
  role: role,
  capabilities: capabilities,
);

void main() {
  late WorkspaceEntityScope? authority;
  late WorkspaceEntityDirectory directory;
  late Map<String, List<Completer<dynamic>>> requests;
  late StreamController<RaftEvent> events;
  setUp(() {
    authority = scope();
    requests = {};
    events = StreamController.broadcast(sync: true);
    directory = WorkspaceEntityDirectory(
      scope: () => authority,
      query: (path) {
        final pending = Completer<dynamic>();
        requests.putIfAbsent(path, () => []).add(pending);
        return pending.future;
      },
      events: events.stream,
    );
  });
  tearDown(() async {
    directory.dispose();
    await events.close();
  });
  Future<void> hydrate() async {
    final pending = directory.preload();
    requests['/agents']!.last.complete([agent]);
    requests['/servers/s/machines']!.last.complete({
      'machines': [computer],
    });
    requests['/servers/s/members']!.last.complete([member]);
    await pending;
  }

  test('Source store cold state coalesces each real endpoint and atomically accepts rows', () async {
    expect(directory.agent('a'), isNull);
    final one = directory.preload(), two = directory.preload();
    expect(
      requests.keys,
      unorderedEquals(['/agents', '/servers/s/machines', '/servers/s/members']),
    );
    expect(requests.values.every((v) => v.length == 1), isTrue);
    expect(directory.state(WorkspaceEntityKind.agents).loading, isTrue);
    expect(directory.state(WorkspaceEntityKind.agents).loaded, isFalse);
    requests['/agents']!.single.complete([agent]);
    requests['/servers/s/machines']!.single.complete([computer]);
    requests['/servers/s/members']!.single.complete([member]);
    await Future.wait([one, two]);
    expect(directory.agent('a'), agent);
    expect(directory.computer('c'), computer);
    expect(directory.member('u'), member);
    expect(directory.state(WorkspaceEntityKind.agents).loaded, isTrue);
    expect(directory.state(WorkspaceEntityKind.agents).loading, isFalse);
    directory.agent('a')!['name'] = 'mutated outside owner';
    expect(directory.agent('a')!['name'], 'Source Agent');
  });
  test(
    'Source machineStore refresh failure retains real accepted rows plus error',
    () async {
      await hydrate();
      final pending = directory.refresh(WorkspaceEntityKind.computers);
      expect(directory.computer('c'), computer);
      expect(directory.state(WorkspaceEntityKind.computers).loaded, isTrue);
      requests['/servers/s/machines']!.last.completeError(
        StateError('offline'),
      );
      await pending;
      expect(directory.computer('c'), computer);
      expect(
        directory.state(WorkspaceEntityKind.computers).error,
        isA<StateError>(),
      );
    },
  );
  test(
    'malformed directory cannot fabricate an empty successful load',
    () async {
      final pending = directory.refresh(WorkspaceEntityKind.computers);
      requests['/servers/s/machines']!.last.complete({'machines': 'invalid'});
      await pending;
      expect(directory.state(WorkspaceEntityKind.computers).loaded, isFalse);
      expect(
        directory.state(WorkspaceEntityKind.computers).error,
        isA<FormatException>(),
      );
    },
  );
  for (final (label, next) in <(String, WorkspaceEntityScope?)>[
    ('server', scope(server: 'other')),
    ('principal without generation change', scope(principal: 'bob')),
    ('role without generation change', scope(role: 'member')),
    ('generation', scope(generation: 2)),
    (
      'origin',
      const WorkspaceEntityScope(
        origin: 'https://other.test',
        principal: 'alice',
        serverId: 's',
        generation: 1,
        role: 'owner',
        capabilities: {...WorkspaceEntityKind.values},
      ),
    ),
    ('same-role capability loss', scope(capabilities: {})),
    ('revocation', null),
  ]) {
    test(
      'Source epoch plus Flutter authority: $label removes accepted data and rejects late replies',
      () async {
        await hydrate();
        final pending = directory.refresh(WorkspaceEntityKind.agents);
        authority = next;
        expect(directory.agent('a'), isNull);
        expect(directory.computer('c'), isNull);
        expect(directory.member('u'), isNull);
        requests['/agents']!.last.complete([agent]);
        await pending;
        expect(directory.agent('a'), isNull);
      },
    );
  }
  test(
    'denied endpoint response retires rows instead of retaining private data',
    () async {
      await hydrate();
      final pending = directory.refresh(WorkspaceEntityKind.members);
      requests['/servers/s/members']!.last.completeError(
        const RaftApiException('Denied', status: 403),
      );
      await pending;
      expect(directory.member('u'), isNull);
      expect(
        directory.state(WorkspaceEntityKind.members).error,
        isA<RaftApiException>(),
      );
    },
  );
  test('Source agentStore newer socket activity survives older pending list snapshot', () async {
    await hydrate();
    final pending = directory.refresh(WorkspaceEntityKind.agents);
    events.add(
      RaftEvent('agent:activity', {
        'agentId': 'a',
        'activity': 'working',
        'detail': 'New real push',
      }),
    );
    expect(directory.agent('a')!['activity'], 'working');
    requests['/agents']!.last.complete([agent]);
    await pending;
    expect(directory.agent('a')!['activity'], 'working');
    expect(directory.agent('a')!['activityDetail'], 'New real push');
  });
  test(
    'Source local/channel/remote projection availability keeps id-only shell',
    () {
      expect(canRenderWorkspaceAgent({'id': 'a'}, 's'), isFalse);
      expect(canRenderWorkspaceAgent({...agent, 'model': null}, 's'), isFalse);
      expect(canRenderWorkspaceAgent(agent, 's'), isTrue);
      expect(
        canRenderWorkspaceAgent({
          'id': 'a',
          'name': 'public',
          'status': 'active',
          'profileProjection': 'channel_summary',
        }, 's'),
        isTrue,
      );
      expect(
        canRenderWorkspaceAgent({
          'id': 'a',
          'name': 'remote',
          'status': 'active',
          'serverId': 'remote',
          'displayName': null,
          'avatarUrl': null,
        }, 's'),
        isTrue,
      );
      expect(
        canRenderWorkspaceAgent({...agent, 'deletedAt': 'now'}, 's'),
        isFalse,
      );
      expect(
        canRenderWorkspaceAgent({
          'id': 'a',
          'name': 'remote',
          'status': 'active',
          'serverId': 'remote',
        }, 's'),
        isFalse,
      );
      expect(canRenderWorkspaceComputer({'id': 'c'}), isFalse);
    },
  );
}
