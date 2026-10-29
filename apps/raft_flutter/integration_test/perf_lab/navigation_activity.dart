import 'dart:async';
import 'dart:developer' as developer;

import 'package:raft_flutter/data/workspace_controller.dart';

import 'fixtures.dart';

/// Stateful server/event replay for mobile navigation, not a widget animation
/// demo. Both reads and mutations enter through the production client,
/// workspace ledger and entity directory. Only the remote transport is local.
/// Timings are fixed so before/after builds receive the same workload.
class LabNavigationActivity {
  LabNavigationActivity({
    required this.workspace,
    required this.client,
    required this.channels,
    required this.agents,
    required this.machines,
  });

  final WorkspaceController workspace;
  final LabClient client;
  final List<LabChannel> channels;
  final List<Map<String, dynamic>> agents, machines;
  int _revision = 0;

  /// Overlap accepted events and the reads they trigger with the SDK's 450 ms
  /// transition. Offscreen channels also change, as they do in the real app.
  /// All timers are joined; no delayed mutations leak into the next scenario.
  Future<Map<String, Object?>> transition({LabChannel? foreground}) async {
    final revision = ++_revision;
    final channel = foreground ?? channels[(revision - 1) % channels.length];
    final background = channels.firstWhere((c) => c != channel);
    final start = developer.Timeline.now;
    final events = <Map<String, Object?>>[];
    final accepted = <String, int>{};
    var notifications = 0;
    void changed() => notifications++;
    workspace.addListener(changed);

    Future<void> at(int milliseconds, void Function() action) async {
      await Future<void>.delayed(Duration(milliseconds: milliseconds));
      action();
    }

    void emit(String name, Map<String, dynamic> payload) {
      events.add({'event': name, 'atUs': developer.Timeline.now - start});
      client.emit(name, payload);
    }

    void check(String name, bool value) {
      if (!value) throw StateError('Live navigation $name was not accepted');
      accepted.update(name, (n) => n + 1, ifAbsent: () => 1);
    }

    final liveId = 'nav-live-$revision';
    final otherId = 'nav-background-$revision';
    final agentId = 'nav-agent-$revision';
    final content =
        'Live edit $revision: 中文、English and an accepted message update';
    Map<String, dynamic> incoming(LabChannel c, String id, String kind) {
      final sequence = int.parse(c.rows.last['seq'] as String) + 1;
      return labRow(c.id, kind, sequence - 1, id: id, others: true);
    }

    try {
      await Future.wait([
        at(40, () {
          final row = incoming(
            channel,
            liveId,
            revision.isOdd ? 'image' : 'markdown',
          );
          row.addAll({
            'taskId': 'nav-task-$revision',
            'taskNumber': 5000 + revision,
            'taskTitle': 'Live task $revision',
            'taskStatus': 'todo',
          });
          channel.rows.add(row);
          channel.tasks.add({
            'id': row['taskId'],
            'messageId': liveId,
            'channelId': channel.id,
            'taskNumber': row['taskNumber'],
            'title': row['taskTitle'],
            'status': 'todo',
          });
          emit('message:new', row);
          check(
            'messageCreate',
            workspace.messageDomain.ledger.contains(channel.id, liveId),
          );
        }),
        at(80, () {
          final machine = machines.first;
          // A newer status version is an accepted status transition even when
          // the machine remains online; it also schedules the recovery reads.
          machine['statusVersion'] = revision;
          emit('machine:status', {
            'machineId': machine['id'],
            'status': machine['status'],
            'statusVersion': revision,
          });
          check(
            'computerStatus',
            workspace.entityDirectory.computer(
                  machine['id'],
                )?['statusVersion'] ==
                revision,
          );
        }),
        at(110, () {
          final activity = revision.isOdd ? 'working' : 'online';
          agents.first['activity'] = activity;
          emit('agent:activity', {
            'agentId': agents.first['id'],
            'activity': activity,
          });
          check(
            'agentActivity',
            workspace.entityDirectory.agent(agents.first['id'])?['activity'] ==
                activity,
          );
        }),
        at(140, () {
          final edited = channel.rows.firstWhere((r) => r['id'] == liveId);
          edited['content'] = content;
          emit('message:updated', Map.of(edited));
          check(
            'messageEdit',
            workspace.messageDomain.ledger.message(
                  channel.id,
                  liveId,
                )?['content'] ==
                content,
          );
        }),
        at(170, () {
          final agent = <String, dynamic>{
            ...agents.first,
            'id': agentId,
            'name': agentId,
            'displayName': 'Live worker $revision',
            'description': 'Created during navigation',
          };
          agents.add(agent);
          emit('agent:created', {'agent': agent});
          check(
            'agentCreate',
            workspace.entityDirectory.agent(agentId) != null,
          );
        }),
        at(210, () {
          final row = incoming(background, otherId, 'plain');
          background.rows.add(row);
          emit('message:new', row);
          check(
            'backgroundMessage',
            workspace.messageDomain.ledger.contains(background.id, otherId),
          );
        }),
        at(260, () {
          agents.first['description'] = 'Live description $revision';
          emit('agent:updated', {'agentId': agents.first['id']});
        }),
        at(310, () {
          final row = channel.rows.firstWhere((r) => r['id'] == liveId);
          row['taskStatus'] = 'in_progress';
          channel.tasks.lastWhere(
            (task) => task['messageId'] == liveId,
          )['status'] = 'in_progress';
          emit('message:updated', Map.of(row));
          check(
            'messageTaskUpdate',
            workspace.messageDomain.ledger.message(
                  channel.id,
                  liveId,
                )?['taskStatus'] ==
                'in_progress',
          );
        }),
        at(360, () {
          agents.removeWhere((a) => a['id'] == agentId);
          emit('agent:deleted', {'agentId': agentId});
          check(
            'agentDelete',
            workspace.entityDirectory.agent(agentId) == null,
          );
        }),
      ]);
      // The agent edit is a catalog invalidation, not a pushed full row. Wait
      // for the production debounce and async revalidation to accept it.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      check(
        'agentRevalidation',
        workspace.entityDirectory.agent(agents.first['id'])?['description'] ==
            'Live description $revision',
      );
      check(
        'editedMessageRetained',
        workspace.messageDomain.ledger.message(
              channel.id,
              liveId,
            )?['content'] ==
            content,
      );
      return {
        'events': events,
        'accepted': accepted,
        'workspaceNotifications': notifications,
      };
    } finally {
      workspace.removeListener(changed);
    }
  }
}
