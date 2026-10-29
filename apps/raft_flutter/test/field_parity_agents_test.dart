import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/migration_error.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/agent_avatar_projection.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

dynamic fixture(String name) => jsonDecode(
  File('test/fixtures/field_parity/$name.json').readAsStringSync(),
);

List<Map<String, dynamic>> rows(String name) => [
  for (final r in fixture(name) as List) Map<String, dynamic>.from(r as Map),
];

void main() {
  group('REST activityDetailKind', () {
    final loop = rows('agents-list-wake-crash-loop');

    test('rows keep the typed kind Web shows (not the socket-only key)', () {
      expect(agentRowDetailKind(loop[0]), 'wake_crash_loop_blocked');
      expect(agentRowActivity(loop[0]).detailKind, 'wake_crash_loop_blocked');
      expect(agentRowActivity(loop[1]).detailKind, 'delivery_unconsumed');
      // Socket patches written by the directory use the other key.
      expect(agentRowDetailKind({'detailKind': 'running_command'}), 'running_command');
    });

    test('Web copy for the paused and unconsumed rows', () {
      expect(
        agentDisplayText(agentRowAmbientDisplay(loop[0])),
        'Automatic wake paused — start manually',
      );
      expect(
        agentDisplayText(agentRowAmbientDisplay(loop[1])),
        'Messages delivered, runtime not responding',
      );
      expect(
        computerAgentActivityText(loop[0]),
        'Automatic wake paused — start manually',
      );
    });
  });

  group('agentActivityText (Web utils/activity.ts)', () {
    test('managed error row extracts the JSON message', () {
      final managed = rows('agents-list-managed-agent').single;
      expect(
        agentDisplayText(agentRowAmbientDisplay(managed)),
        'Error: Authentication failed: invalid x-api-key',
      );
      expect(
        computerAgentActivityText(managed),
        'Error: Authentication failed: invalid x-api-key',
      );
    });

    test('fixed labels, ellipses and raw passthrough', () {
      expect(agentActivityText('online', 'ignored', null), 'Online');
      expect(agentActivityText('thinking', 'some detail', 'other'), 'Thinking…');
      expect(agentActivityText('working', '', null), 'Working…');
      expect(agentActivityText('working', 'Running tests', 'running_command'), 'Running tests');
      expect(agentActivityText('working', 'x', 'starting'), 'Starting…');
      expect(agentActivityText('working', 'x', 'runtime_starting'), 'Starting…');
      expect(agentActivityText('working', 'x', 'compacting_context'), 'Compacting context…');
      expect(agentActivityText('error', '', null), 'Error');
      expect(agentActivityText('error', 'plain failure', null), 'Error: plain failure');
      expect(agentActivityText('error', '{"error":{"message":" nested "}}', null), 'Error: nested');
      expect(agentActivityText('error', '{"errors":[{"message":"first"}]}', null), 'Error: first');
      expect(agentActivityText('error', '{broken', null), 'Error: {broken');
      expect(agentActivityText('offline', '', null), 'Offline');
      expect(agentActivityText('offline', 'Stopped', 'stopped'), "Stopped — won't receive messages until restarted");
      expect(agentActivityText('offline', 'Start failed: no disk', 'runtime_unavailable'), 'Start failed: no disk');
      expect(agentActivityText('offline', '', 'runtime_unavailable'), 'Offline');
      expect(agentActivityText('terminal_failure_paused_x', '', null), 'terminal_failure_paused_x');
    });

    test('terminal failure pause uses the server detail when present', () {
      expect(
        agentActivityText('offline', 'Paused until 10:00', 'terminal_failure_paused'),
        'Paused until 10:00',
      );
      expect(
        agentActivityText('offline', '', 'terminal_failure_paused'),
        'Automatic wake paused after repeated runtime failures — a manual start lifts it',
      );
    });

    test('withDetail:false drops the detail like a public projection', () {
      final display = agentRowAmbientDisplay(
        rows('agents-list-managed-agent').single,
      );
      expect(agentDisplayText(display, withDetail: false), 'Error');
    });
  });

  group('external presence from lastSeenAt', () {
    final external = rows('agents-list-external-agent').single;
    final seen = DateTime.parse(external['lastSeenAt'] as String);

    test('Web resolveAgentDisplayState: the hydrated offline wins while seen', () {
      // REST serves activity "offline" for external agents and Web hydrates it
      // as an explicit activity state, so a seen agent still reads offline.
      final recent = seen.add(const Duration(seconds: 90));
      final display = agentRowAmbientDisplay(external, now: recent);
      expect(display.activity, 'offline');
      expect(agentRowPresence(external, now: recent).activity, RaftAvatarActivity.offline);
    });

    test('without a hydrated activity the lastSeenAt window decides', () {
      final bare = Map<String, dynamic>.of(external)
        ..remove('activity')
        ..['status'] = 'inactive';
      final recent = seen.add(const Duration(seconds: 90));
      expect(agentRowAmbientDisplay(bare, now: recent).activity, 'offline');
      // The ambient rule: a row with no live entry is normalised by status,
      // so use the identity path shared by thread followers / created agents.
      final display = resolveAgentAmbientDisplay(
        identity: AgentPresentationIdentity(
          id: 'x',
          status: 'inactive',
          runtime: 'external',
          lastSeenAt: seen,
        ),
        now: recent,
      );
      expect(display.activity, 'online');
      expect(agentDisplayText(display, lastSeenAt: seen), 'Online');
    });

    test('a live frame is honoured only while the credential is seen', () {
      final recent = seen.add(const Duration(seconds: 90));
      final working = {'activity': 'working', 'detail': 'Editing'};
      expect(
        agentRowAmbientDisplay(external, live: working, now: recent).activity,
        'working',
      );
      expect(
        agentRowPresence(external, live: 'working', now: recent).activity,
        RaftAvatarActivity.working,
      );
      final later = DateTime.parse('2026-10-12T10:30:00.000Z');
      final stale = agentRowAmbientDisplay(external, live: working, now: later);
      expect(stale.activity, 'offline');
      expect(
        agentDisplayText(
          stale,
          lastSeenAt: seen,
          relativeTime: (_) => '35 minutes ago',
        ),
        'Last active 35 minutes ago',
      );
      expect(computerAgentActivityText(external, now: later), 'Offline');
    });
  });

  group('status fallback when activity is absent', () {
    test('uses normalizeActivity(activityKind ?? activity, status)', () {
      expect(agentRowActivity({'status': 'active'}).activity, 'working');
      expect(agentRowActivity({'status': 'inactive'}).activity, 'offline');
      expect(
        agentRowActivity({'status': 'active', 'activityKind': 'thinking', 'activity': 'online'}).activity,
        'thinking',
      );
      expect(agentRowActivity({'status': 'active', 'activity': 'bogus'}).activity, 'working');
    });

    test('fleet subtitle is a label, not a raw enum', () {
      final text = agentDisplayText(
        agentRowAmbientDisplay({'id': 'a', 'status': 'inactive'}),
      );
      expect(text, 'Offline');
    });
  });

  group('serverRole chip', () {
    test('known, unrecognized (title-cased), absent and deleted', () {
      final managed = rows('agents-list-managed-agent').single;
      final owner = agentServerRoleChip(managed['serverRole']);
      expect(owner!.known, isFalse);
      expect(owner.label, 'Owner');
      expect(agentServerRoleChip('admin')!.known, isTrue);
      expect(agentServerRoleChip('member')!.label, 'member');
      expect(agentServerRoleChip('guest')!.label, 'Guest');
      expect(agentServerRoleChip(null), isNull);
      expect(agentServerRoleChip('  '), isNull);
      expect(agentServerRoleChip('admin', deletedAt: '2026-10-01T00:00:00Z'), isNull);
    });
  });

  group('displayName empty-string fallback', () {
    test('created agent with "" displayName falls back to the handle', () {
      final managed = rows('agents-list-managed-agent').single;
      final created = (managed['createdAgents'] as List).single as Map;
      expect(created['displayName'], '');
      expect(agentRowName(created), 'scout');
      expect(nonEmptyOr('', 'x'), 'x');
      expect(nonEmptyOr(null, 'x'), 'x');
      expect(nonEmptyOr('A', 'x'), 'A');
      expect(nonEmptyOr(null, null), '');
    });

    test('created agent dot is offline for a stopped agent', () {
      final managed = rows('agents-list-managed-agent').single;
      final created = (managed['createdAgents'] as List).single as Map;
      final display = resolveAgentAmbientDisplay(
        identity: AgentPresentationIdentity(
          id: '${created['id']}',
          status: created['status'] as String,
          runtime: created['runtime'] as String?,
        ),
        now: DateTime.now(),
      );
      expect(display.activity, 'offline');
      expect(display.detailKind, 'stopped');
    });
  });

  group('workspace entity directory agent:activity', () {
    late WorkspaceEntityDirectory directory;
    late StreamController<RaftEvent> events;
    final managed = rows('agents-list-managed-agent').single;
    final frame =
        Map<String, dynamic>.from(
              (fixture('agents-socket-frames') as Map).entries
                  .firstWhere((e) => (e.key as String).startsWith('agent:activity'))
                  .value as Map,
            );

    setUp(() async {
      events = StreamController.broadcast(sync: true);
      directory = WorkspaceEntityDirectory(
        scope: () => const WorkspaceEntityScope(
          origin: 'https://fixture.test',
          principal: 'alice',
          serverId: 's',
          generation: 1,
          role: 'owner',
          capabilities: {WorkspaceEntityKind.agents},
        ),
        query: (path) async => path == '/agents' ? [managed] : <dynamic>[],
        events: events.stream,
      );
      await directory.refresh(WorkspaceEntityKind.agents);
    });
    tearDown(() async {
      directory.dispose();
      await events.close();
    });

    test('applies activity, detail and keeps detailKind', () {
      events.add(RaftEvent('agent:activity', frame));
      final row = directory.agent(frame['agentId'] as String)!;
      expect(row['activity'], 'working');
      expect(row['activityDetail'], 'Running tests');
      expect(agentRowDetailKind(row), 'running_command');
      expect(agentDisplayText(agentRowAmbientDisplay(row)), 'Running tests');
    });

    test('drops stale serverSeq and unknown activities', () {
      events.add(RaftEvent('agent:activity', frame));
      events.add(
        RaftEvent('agent:activity', {
          ...frame,
          'activity': 'offline',
          'activityKind': 'offline',
          'detail': '',
          'serverSeq': (frame['serverSeq'] as int) - 1,
        }),
      );
      var row = directory.agent(frame['agentId'] as String)!;
      expect(row['activity'], 'working');
      events.add(
        RaftEvent('agent:activity', {
          ...frame,
          'activity': 'bogus',
          'activityKind': 'bogus',
          'serverSeq': (frame['serverSeq'] as int) + 5,
        }),
      );
      row = directory.agent(frame['agentId'] as String)!;
      expect(row['activity'], 'working');
      events.add(
        RaftEvent('agent:activity', {
          ...frame,
          'activity': 'online',
          'activityKind': 'online',
          'detail': '',
          'detailKind': 'idle',
          'serverSeq': (frame['serverSeq'] as int) + 6,
        }),
      );
      row = directory.agent(frame['agentId'] as String)!;
      expect(row['activity'], 'online');
      expect(row['activityDetail'], '');
    });

    test('activityKind wins over activity', () {
      events.add(
        RaftEvent('agent:activity', {
          ...frame,
          'activity': 'working',
          'activityKind': 'thinking',
        }),
      );
      expect(directory.agent(frame['agentId'] as String)!['activity'], 'thinking');
    });

    test('a reconnect resets the seq baseline', () {
      events.add(RaftEvent('agent:activity', frame));
      events.add(const RaftEvent('connected', {}));
      events.add(
        RaftEvent('agent:activity', {
          ...frame,
          'activity': 'online',
          'activityKind': 'online',
          'detail': '',
          'serverSeq': 1,
        }),
      );
      expect(directory.agent(frame['agentId'] as String)!['activity'], 'online');
    });
  });

  group('agent migration view', () {
    test('unknown states have no phase', () {
      expect(migrationPhase('waiting_for_target'), isNull);
      expect(migrationPhase('in_transit'), 'active');
    });
  });
}
