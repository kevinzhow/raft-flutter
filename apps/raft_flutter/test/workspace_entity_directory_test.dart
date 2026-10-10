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
  test('shared author directory keeps tombstones, revalidates in place and fences superseded or cross-identity reads', () async {
    const tombstone = {'id': 'gone', 'name': 'gone', 'deletedAt': 'then'};
    expect(directory.authorsLoading, isTrue);
    directory.ensureAuthors();
    directory.ensureAuthors();
    expect(requests['/agents'], hasLength(1));
    expect(requests['/servers/s/members'], hasLength(1));
    expect(requests.containsKey('/servers/s/machines'), isFalse);
    requests['/agents']!.single.complete([agent, tombstone]);
    requests['/servers/s/members']!.single.complete([member]);
    await Future<void>.delayed(Duration.zero);
    expect(directory.authorsLoading, isFalse);
    expect(directory.authorAgents.map((r) => r['id']), ['a', 'gone']);
    expect(directory.authorMembers.single['userId'], 'u');
    // A tombstone identifies a historical sender, never a live entity.
    expect(directory.agent('gone'), isNull);
    expect(directory.rows(WorkspaceEntityKind.agents), hasLength(1));

    final revision = directory.agentRevision;
    final requestRevision = directory.agentRequestRevision;
    directory.revalidateAuthors();
    expect(directory.agentRequestRevision, requestRevision + 1);
    directory.revalidateAuthors();
    expect(requests['/agents'], hasLength(3));
    // Stale-while-revalidate: accepted lists stay, nothing reports loading.
    expect(directory.authorsLoading, isFalse);
    expect(directory.authorAgents, hasLength(2));
    // The superseded read is dropped even when it lands last.
    requests['/agents']![2].complete([
      {...agent, 'name': 'Renamed'},
    ]);
    await Future<void>.delayed(Duration.zero);
    requests['/agents']![1].complete([agent, tombstone]);
    await Future<void>.delayed(Duration.zero);
    expect(directory.agentRevision, revision + 1);
    expect(directory.authorAgents.single['name'], 'Renamed');

    // A read in flight under the old identity never lands in the new one.
    directory.revalidateAuthors();
    authority = scope(role: 'member');
    expect(directory.authorAgents, isEmpty);
    expect(directory.authorsLoading, isTrue);
    requests['/agents']!.last.complete([agent, tombstone]);
    await Future<void>.delayed(Duration.zero);
    expect(directory.authorAgents, isEmpty);
  });
  group('realtime events (Source socketBridge parity)', () {
    int reads(String path) => requests[path]?.length ?? 0;
    Map<String, int> counts() => {
      for (final entry in requests.entries) entry.key: entry.value.length,
    };
    // Coalescing window plus margin; the directory runs on the real clock.
    Future<void> settle() => Future<void>.delayed(
      WorkspaceEntityDirectory.reloadDelay + const Duration(milliseconds: 50),
    );

    test('presence and session events patch the row with zero HTTP', () async {
      await hydrate();
      final before = counts();
      var notifications = 0;
      directory.addListener(() => notifications++);
      final authors = directory.authorAgents;
      events.add(
        const RaftEvent('agent:seen', {
          'agentId': 'a',
          'lastSeenAt': '2026-10-10T10:00:00.000Z',
        }),
      );
      expect(directory.agent('a')!['lastSeenAt'], '2026-10-10T10:00:00.000Z');
      // Older presence is dropped without a notification.
      events.add(
        const RaftEvent('agent:seen', {
          'agentId': 'a',
          'lastSeenAt': '2026-10-10T09:00:00.000Z',
        }),
      );
      expect(directory.agent('a')!['lastSeenAt'], '2026-10-10T10:00:00.000Z');
      events.add(
        const RaftEvent('agent:session', {'agentId': 'a', 'sessionId': 's1'}),
      );
      expect(directory.agent('a')!['sessionId'], 's1');
      events.add(
        const RaftEvent('agent:session', {'agentId': 'a', 'sessionId': 's1'}),
      );
      events.add(
        const RaftEvent('agent:activity', {
          'agentId': 'a',
          'activity': 'working',
          'detail': 'Heartbeat',
        }),
      );
      events.add(
        const RaftEvent('machine:capabilities', {
          'machineId': 'c',
          'runtimes': ['codex', 'claude'],
          'hostname': 'host',
        }),
      );
      expect(directory.computer('c')!['runtimes'], ['codex', 'claude']);
      expect(directory.computer('c')!['hostname'], 'host');
      events.add(
        const RaftEvent('machine:capabilities', {
          'machineId': 'c',
          'runtimes': ['codex', 'claude'],
          'hostname': 'host',
        }),
      );
      // seen, session, activity, capabilities: one notification each; the
      // duplicate frames are no-ops.
      expect(notifications, 4);
      await settle();
      expect(counts(), before);
      // Author identity is unaffected by presence: no author churn.
      expect(identical(directory.authorAgents, authors), isTrue);
    });

    test('machine:status is statusVersion-gated; stale and duplicate frames cost nothing', () async {
      final pending = directory.preload();
      requests['/agents']!.last.complete([agent]);
      requests['/servers/s/machines']!.last.complete([
        {...computer, 'statusVersion': 5},
      ]);
      requests['/servers/s/members']!.last.complete([member]);
      await pending;
      final before = counts();
      var notifications = 0;
      directory.addListener(() => notifications++);
      for (final frame in [
        {'machineId': 'c', 'status': 'offline', 'statusVersion': 4},
        {'machineId': 'c', 'status': 'online', 'statusVersion': 5},
        {'machineId': 'unknown', 'status': 'offline', 'statusVersion': 9},
      ]) {
        events.add(RaftEvent('machine:status', frame));
      }
      await settle();
      expect(directory.computer('c')!['status'], 'online');
      expect(notifications, 0);
      expect(counts(), before);
    });

    test('accepted machine transitions patch at once and coalesce into one machines+agents recovery read', () async {
      await hydrate();
      for (var version = 1; version <= 5; version++) {
        events.add(
          RaftEvent('machine:status', {
            'machineId': 'c',
            'status': version.isOdd ? 'offline' : 'online',
            'statusVersion': version,
          }),
        );
      }
      // The visible row is patched before any request.
      expect(directory.computer('c')!['status'], 'offline');
      expect(directory.computer('c')!['statusVersion'], 5);
      expect(reads('/servers/s/machines'), 1);
      await settle();
      expect(reads('/servers/s/machines'), 2);
      expect(reads('/agents'), 2);
      expect(reads('/servers/s/members'), 1);
    });

    test(
      'catalog events re-read only the affected kind, once per burst',
      () async {
        await hydrate();
        for (var i = 0; i < 5; i++) {
          events.add(const RaftEvent('agent:updated', {'agentId': 'a'}));
        }
        await settle();
        expect(counts(), {
          '/agents': 2,
          '/servers/s/machines': 1,
          '/servers/s/members': 1,
        });
        requests['/agents']!.last.complete([agent]);
        events.add(const RaftEvent('machine:updated', {}));
        await settle();
        expect(counts(), {
          '/agents': 2,
          '/servers/s/machines': 2,
          '/servers/s/members': 1,
        });
        requests['/servers/s/machines']!.last.complete([computer]);
        events.add(
          const RaftEvent('server:member-added', {
            'serverId': 's',
            'userId': 'v',
          }),
        );
        // Another server's membership never reaches this directory.
        events.add(
          const RaftEvent('server:member-added', {
            'serverId': 'other',
            'userId': 'v',
          }),
        );
        await settle();
        expect(counts(), {
          '/agents': 2,
          '/servers/s/machines': 2,
          '/servers/s/members': 2,
        });
      },
    );

    test('agent:created upserts the pushed row and agent:deleted leaves a tombstone before the agent list read', () async {
      await hydrate();
      const created = {
        'id': 'b',
        'name': 'Created agent',
        'status': 'active',
        'runtime': 'codex',
        'model': 'gpt-6',
      };
      events.add(const RaftEvent('agent:created', {'agent': created}));
      expect(directory.agent('b'), created);
      expect(directory.authorAgents.map((row) => row['id']), ['a', 'b']);
      events.add(const RaftEvent('agent:deleted', {'agentId': 'a'}));
      expect(directory.agent('a'), isNull);
      expect(directory.agentDeleted('a'), isTrue);
      expect(directory.rows(WorkspaceEntityKind.agents).single['id'], 'b');
      // A deleted agent still identifies its historical messages.
      final tombstone = directory.authorAgents.firstWhere(
        (row) => row['id'] == 'a',
      );
      expect(tombstone['deletedAt'], isNotNull);
      await settle();
      expect(counts(), {
        '/agents': 2,
        '/servers/s/machines': 1,
        '/servers/s/members': 1,
      });
      requests['/agents']!.last.complete([
        created,
        {...agent, 'deletedAt': '2026-10-10T00:00:00.000Z'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(directory.agent('b'), created);
      expect(
        directory.authorAgents.firstWhere(
          (row) => row['id'] == 'a',
        )['deletedAt'],
        '2026-10-10T00:00:00.000Z',
      );
    });

    test(
      'a change during an in-flight read is followed by exactly one more read',
      () async {
        await hydrate();
        final inFlight = directory.refresh(WorkspaceEntityKind.agents);
        expect(reads('/agents'), 2);
        events.add(const RaftEvent('agent:updated', {'agentId': 'a'}));
        events.add(const RaftEvent('agent:updated', {'agentId': 'a'}));
        await settle();
        // The older read may predate the change; it is not superseded.
        expect(reads('/agents'), 2);
        events.add(const RaftEvent('agent:updated', {'agentId': 'a'}));
        await settle();
        requests['/agents']![1].complete([agent]);
        await inFlight;
        await Future<void>.delayed(Duration.zero);
        expect(reads('/agents'), 3);
      },
    );

    test(
      'presence keeps its newest value across an older list snapshot',
      () async {
        await hydrate();
        final pending = directory.refresh(WorkspaceEntityKind.agents);
        events.add(
          const RaftEvent('agent:seen', {
            'agentId': 'a',
            'lastSeenAt': '2026-10-10T10:00:00.000Z',
          }),
        );
        requests['/agents']!.last.complete([
          {...agent, 'lastSeenAt': '2026-10-10T08:00:00.000Z'},
        ]);
        await pending;
        expect(directory.agent('a')!['lastSeenAt'], '2026-10-10T10:00:00.000Z');
      },
    );

    test(
      'an identity change drops scheduled and in-flight event reads',
      () async {
        await hydrate();
        events.add(const RaftEvent('agent:updated', {'agentId': 'a'}));
        authority = scope(role: 'member');
        directory.synchronize();
        await settle();
        // The scheduled read of the old identity never starts.
        expect(reads('/agents'), 1);
        expect(directory.agent('a'), isNull);

        final pending = directory.preload();
        requests['/agents']!.last.complete([agent]);
        requests['/servers/s/machines']!.last.complete([computer]);
        requests['/servers/s/members']!.last.complete([member]);
        await pending;
        events.add(const RaftEvent('agent:deleted', {'agentId': 'a'}));
        await settle();
        expect(reads('/agents'), 3);
        authority = scope(principal: 'bob');
        expect(directory.authorAgents, isEmpty);
        requests['/agents']!.last.complete([
          {...agent, 'name': 'Old identity reply'},
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(directory.agent('a'), isNull);
        expect(directory.authorAgents, isEmpty);
      },
    );

    test(
      'events before any surface started the directory cost nothing',
      () async {
        events
          ..add(const RaftEvent('agent:updated', {'agentId': 'a'}))
          ..add(const RaftEvent('machine:updated', {}))
          ..add(const RaftEvent('server:member-added', {'serverId': 's'}));
        await settle();
        expect(requests, isEmpty);
      },
    );
  });

  group('device records', () {
    late Map<String, dynamic> disk;
    late WorkspaceEntityDirectory device;
    late Map<String, List<Completer<dynamic>>> reads;
    String key(WorkspaceEntityScope s, WorkspaceEntityKind kind) =>
        '${s.origin}|${s.principal}|${s.serverId}|${kind.name}';
    Map<String, dynamic> record(
      WorkspaceEntityKind kind,
      List<Map<String, dynamic>> rows, {
      String role = 'owner',
      List<Map<String, dynamic>> tombstones = const [],
    }) => {
      'version': WorkspaceEntityDirectory.deviceRecordVersion,
      'kind': kind.name,
      'role': role,
      'rows': rows,
      if (kind == WorkspaceEntityKind.agents) 'tombstones': tombstones,
    };
    setUp(() {
      disk = {};
      reads = {};
      device = WorkspaceEntityDirectory(
        scope: () => authority,
        query: (path) {
          final pending = Completer<dynamic>();
          reads.putIfAbsent(path, () => []).add(pending);
          return pending.future;
        },
        events: events.stream,
        readDevice: (s, kind) async => disk[key(s, kind)],
        writeDevice: (s, kind, value) {
          if (value == null) {
            disk.remove(key(s, kind));
          } else {
            disk[key(s, kind)] = value;
          }
        },
      );
    });
    tearDown(() => device.dispose());

    test(
      'paints the saved rows before the read and replaces them in place',
      () async {
        final s = scope();
        disk[key(s, WorkspaceEntityKind.agents)] = record(
          WorkspaceEntityKind.agents,
          [agent],
          tombstones: [
            {...agent, 'id': 'gone', 'deletedAt': '2026-10-01T00:00:00Z'},
          ],
        );
        disk[key(s, WorkspaceEntityKind.members)] = record(
          WorkspaceEntityKind.members,
          [member],
        );
        expect(device.authorsLoading, isTrue);
        final pending = device.preload();
        await device.restored;
        expect(device.agent('a')?['model'], 'gpt-6');
        expect(device.agentDeleted('gone'), isTrue);
        expect(device.member('u')?['name'], 'Source Human');
        expect(device.authorsLoading, isFalse);
        expect(device.fromDevice(WorkspaceEntityKind.agents), isTrue);
        expect(device.state(WorkspaceEntityKind.agents).loading, isTrue);
        expect(device.state(WorkspaceEntityKind.agents).loaded, isTrue);
        final before = device.agentRevision;
        reads['/agents']!.single.complete([
          {...agent, 'model': 'gpt-7'},
        ]);
        reads['/servers/s/members']!.single.complete([member]);
        reads['/servers/s/machines']!.single.complete({
          'machines': [computer],
        });
        await pending;
        expect(device.agentRevision, isNot(before));
        expect(device.agent('a')?['model'], 'gpt-7');
        expect(device.agentDeleted('gone'), isFalse);
        expect(device.fromDevice(WorkspaceEntityKind.agents), isFalse);
        device.flushDevice();
        final saved = disk[key(s, WorkspaceEntityKind.agents)] as Map;
        expect((saved['rows'] as List).single['model'], 'gpt-7');
        expect(saved['role'], 'owner');
        expect(disk[key(s, WorkspaceEntityKind.computers)], isNotNull);
      },
    );

    test(
      'an accepted read is never overwritten by a late device record',
      () async {
        final gate = Completer<void>();
        final late = WorkspaceEntityDirectory(
          scope: () => authority,
          query: (path) async => path == '/agents'
              ? [
                  {...agent, 'model': 'fresh'},
                ]
              : path.endsWith('/machines')
              ? {'machines': []}
              : [],
          readDevice: (s, kind) async {
            await gate.future;
            return record(
              kind,
              kind == WorkspaceEntityKind.agents ? [agent] : [],
            );
          },
          writeDevice: (_, _, _) {},
        );
        addTearDown(late.dispose);
        await late.preload();
        gate.complete();
        await late.restored;
        expect(late.agent('a')?['model'], 'fresh');
        expect(late.fromDevice(WorkspaceEntityKind.agents), isFalse);
      },
    );

    test(
      'another role or a disallowed kind never paints and is retired',
      () async {
        final s = scope(
          role: 'member',
          capabilities: const {WorkspaceEntityKind.members},
        );
        authority = s;
        disk[key(s, WorkspaceEntityKind.agents)] = record(
          WorkspaceEntityKind.agents,
          [agent],
          role: 'member',
        );
        disk[key(s, WorkspaceEntityKind.members)] = record(
          WorkspaceEntityKind.members,
          [member],
          role: 'owner',
        );
        await device.restored;
        expect(device.authorAgents, isEmpty);
        expect(device.member('u'), isNull);
        expect(device.settled(WorkspaceEntityKind.members), isFalse);
        expect(disk, isEmpty);
      },
    );

    test('a device-painted kind is still read once by ensure', () async {
      final s = scope();
      disk[key(s, WorkspaceEntityKind.computers)] = record(
        WorkspaceEntityKind.computers,
        [computer],
      );
      await device.restored;
      expect(device.settled(WorkspaceEntityKind.computers), isTrue);
      expect(reads, isEmpty);
      device.ensure(const [WorkspaceEntityKind.computers]);
      expect(reads.keys, ['/servers/s/machines']);
      device.ensure(const [WorkspaceEntityKind.computers]);
      expect(reads['/servers/s/machines'], hasLength(1));
    });

    test(
      'a refusal deletes the record; unwritten changes never cross scopes',
      () async {
        final s = scope();
        disk[key(s, WorkspaceEntityKind.agents)] = record(
          WorkspaceEntityKind.agents,
          [agent],
        );
        await device.restored;
        expect(device.agent('a'), isNotNull);
        final pending = device.refresh(WorkspaceEntityKind.agents);
        reads['/agents']!.single.completeError(
          const RaftApiException('Forbidden', status: 403),
        );
        await pending;
        expect(device.agent('a'), isNull);
        device.flushDevice();
        expect(disk[key(s, WorkspaceEntityKind.agents)], isNull);

        // A patch scheduled under the owner role is dropped by a role change.
        final second = device.refresh(WorkspaceEntityKind.computers);
        reads['/servers/s/machines']!.single.complete({
          'machines': [computer],
        });
        await second;
        authority = scope(role: 'admin');
        device.synchronize();
        device.flushDevice();
        expect(disk[key(s, WorkspaceEntityKind.computers)], isNull);
      },
    );
  });
}
