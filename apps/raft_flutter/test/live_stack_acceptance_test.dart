// WP-LIVE acceptance against a running Raft v1.24 server: one signed-in
// "app" (WorkspaceController with its socket) and a second "other device"
// client of the same person. Skipped unless RAFT_LIVE_STACK_FIXTURE (a
// fixture JSON with accounts.owner {email, password} and server.id) and
// RAFT_LIVE_STACK_ORIGIN (API origin) are set. Every change it makes to the
// account (display name, theme) is put back at the end.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/actor_directory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_live_sync.dart';
import 'package:raft_sync/raft_sync.dart';

final _fixturePath = Platform.environment['RAFT_LIVE_STACK_FIXTURE'];
final _origin = Platform.environment['RAFT_LIVE_STACK_ORIGIN'];

Future<void> _until(bool Function() done, {int seconds = 15}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!done()) {
    if (DateTime.now().isAfter(end)) throw StateError('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  final skip = _fixturePath == null || _origin == null
      ? 'set RAFT_LIVE_STACK_FIXTURE and RAFT_LIVE_STACK_ORIGIN'
      : false;

  test(
    'live v1.24 stack: sync cursor, profile, theme, gap fill, actors',
    () async {
      final fixture = jsonDecode(File(_fixturePath!).readAsStringSync()) as Map;
      final owner = fixture['accounts']['owner'] as Map;
      final serverId = fixture['server']['id'] as String;
      Future<RaftClient> signIn() async {
        final c = RaftClient(
          origin: _origin!,
          sessionStore: MemorySessionStore(),
        );
        await c.login(owner['email'] as String, owner['password'] as String);
        c.selectServer(serverId);
        return c;
      }

      final app = await signIn(), other = await signIn();
      final events = <String>[];
      final listening = app.events.listen((e) => events.add(e.name));
      final w = WorkspaceController(app);
      final me = await other.get('/auth/me') as Map;
      final appearance =
          await other.get('/servers/$serverId/appearance-settings') as Map;
      final report = <String, Object?>{};
      try {
        await w.bootstrap();
        app.connect();
        await _until(() => events.contains('rooms:joined'));

        // 1. GET /sync/changes: the contract answers a cursor, then changes.
        final first =
            await other.getForServer(serverId, '/sync/changes') as Map;
        report['syncCursor'] = first['cursor'] is String;
        final plan = planSyncChanges(
          ((await other.getForServer(
                serverId,
                '/sync/changes',
                query: {'since': first['cursor']},
              )) as Map)['changes']
              as List,
        );
        report['syncEmptyPlan'] = plan.snapshots.isEmpty;
        // A reconnect takes the session's cursor.
        app.suspendConnection();
        await _until(() => !app.connected);
        events.clear();
        app.connect();
        await _until(() => events.contains('rooms:joined'));
        await _until(
          () => WorkspaceLiveSync.of(app).syncSession?.hasCursor == true,
        );
        report['reconnectTookCursor'] = true;

        // 2. user:profile-updated from the other device.
        final name = 'Live ${DateTime.now().millisecondsSinceEpoch % 100000}';
        await other.patch('/auth/me', data: {'displayName': name});
        await _until(() => app.user?.json['displayName'] == name);
        report['profileFollowed'] = true;

        // 3. appearance:updated from the other device.
        await other.patch(
          '/servers/$serverId/appearance-settings',
          data: {'theme': 'space'},
        );
        await _until(
          () => w.servers.any(
            (s) => s.id == serverId && s.json['theme'] == 'space',
          ),
        );
        report['themeFollowed'] = true;

        // 4. A live row across a seq jump: the hole behind it is read.
        final general = (fixture['channel'] as Map)['id'] as String;
        await w.selectChannel(w.channels.firstWhere((c) => c.id == general));
        await _until(() => w.messageDomain.messages.isNotEmpty);
        final sent = await other.send(general, 'WP-LIVE gap fill probe');
        await _until(
          () => w.messageDomain.messages.any((m) => m.id == sent.id),
        );
        final fill = LiveGapFill.of(w.messageDomain.ledger);
        await _until(() => !fill.owes(general));
        report['gapFilled'] = true;

        // 5. POST /actors/resolve answers for this server.
        final agent = (fixture['agent'] as Map)['id'] as String;
        final actors = ActorDirectory.of(app)
          ..request([(kind: 'agent', id: agent)]);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        report['actorResolved'] = actors.row('agent', agent) != null;
      } finally {
        await other.patch('/auth/me', data: {'displayName': me['displayName']});
        await other.patch(
          '/servers/$serverId/appearance-settings',
          data: {'theme': appearance['theme']},
        );
        // ignore: avoid_print
        print('live-stack: ${jsonEncode(report)}');
        await listening.cancel();
        w.dispose();
        await app.dispose();
        await other.dispose();
      }
      expect(report['syncCursor'], isTrue);
      expect(report['reconnectTookCursor'], isTrue);
      expect(report['profileFollowed'], isTrue);
      expect(report['themeFollowed'], isTrue);
      expect(report['gapFilled'], isTrue);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
