// WP-LIVE: server v1.24 entity events the shared directory applies in place.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

const _server = '22222222-2222-4222-8222-222222222222';
const _user = '11111111-1111-4111-8111-111111111111';

void main() {
  late WorkspaceEntityDirectory directory;
  late StreamController<RaftEvent> events;
  final requests = <String, Completer<dynamic>>{};
  setUp(() async {
    requests.clear();
    events = StreamController.broadcast(sync: true);
    directory = WorkspaceEntityDirectory(
      scope: () => WorkspaceEntityScope(
        origin: 'https://fixture.test',
        principal: 'alice',
        serverId: _server,
        generation: 1,
        role: 'owner',
        capabilities: {...WorkspaceEntityKind.values},
      ),
      query: (path) => (requests[path] = Completer<dynamic>()).future,
      events: events.stream,
    );
    final pending = directory.preload();
    requests['/agents']!.complete([
      {'id': 'a', 'name': 'Agent', 'activity': 'online', 'status': 'active'},
    ]);
    requests['/servers/$_server/machines']!.complete({'machines': []});
    requests['/servers/$_server/members']!.complete([
      {'userId': _user, 'name': 'old', 'displayName': null, 'role': 'member'},
      {'userId': 'other', 'name': 'other', 'role': 'member'},
    ]);
    await pending;
  });
  tearDown(() async {
    directory.dispose();
    await events.close();
  });

  test('user:profile-updated patches that member in place, no list read', () {
    final other = directory.member('other');
    var notified = 0;
    directory.addListener(() => notified++);
    requests.clear();
    events.add(
      const RaftEvent('user:profile-updated', {
        'serverId': _server,
        'userId': _user,
        'name': 'new',
        'displayName': 'New Name',
        'avatarUrl': '/avatars/new.png',
        'gravatarHash': '',
      }),
    );
    expect(directory.member(_user)!['displayName'], 'New Name');
    expect(directory.member(_user)!['avatarUrl'], '/avatars/new.png');
    expect(directory.member(_user)!['role'], 'member');
    expect(directory.member('other'), other);
    expect(notified, 1);
    expect(requests, isEmpty);
    // The same profile again changes nothing.
    events.add(
      const RaftEvent('user:profile-updated', {
        'serverId': _server,
        'userId': _user,
        'name': 'new',
        'displayName': 'New Name',
        'avatarUrl': '/avatars/new.png',
      }),
    );
    expect(notified, 1);
  });

  test('[BP-RT-025] agent:activity_state moves the coarse activity with the '
      'serverSeq order of agent:activity', () {
    events.add(
      const RaftEvent('agent:activity_state', {
        'agentId': 'a',
        'state': 'busy',
        'activity': 'working',
        'timestamp': 1,
        'serverSeq': 5,
      }),
    );
    expect(directory.agent('a')!['activity'], 'working');
    events.add(
      const RaftEvent('agent:activity_state', {
        'agentId': 'a',
        'state': 'online',
        'activity': 'online',
        'timestamp': 0,
        'serverSeq': 4,
      }),
    );
    expect(directory.agent('a')!['activity'], 'working', reason: 'stale seq');
  });
}
