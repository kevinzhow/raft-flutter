import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/message_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';

import 'message_agent_presentation_test.dart' show accepted, agent;
import 'message_presentation_test.dart' show fixture;

class _ObservedPresentation extends MessageAgentPresentation {
  _ObservedPresentation(super.workspace, super.directory);

  final reads = <String>[];

  @override
  AgentPresentationIdentity? identity(String id) {
    reads.add(id);
    return super.identity(id);
  }
}

Future<(WorkspaceController, MessageReferenceDirectory)> _directory() async {
  final (w, transport) = await fixture('owner');
  addTearDown(w.dispose);
  transport.routes['GET /agents'] = (_) => [
    for (var i = 0; i < 100; i++) {...agent, 'id': 'agent-$i'},
  ];
  transport.routes['GET /servers/s1/members'] = (_) => [];
  final directory = MessageReferenceDirectory(w);
  addTearDown(directory.dispose);
  await accepted(directory);
  return (w, directory);
}

void main() {
  test('repeated sender reads reuse an unchanged immutable identity', () async {
    final (w, directory) = await _directory();
    final presentation = MessageAgentPresentation(w, directory);
    addTearDown(presentation.dispose);
    final first = presentation.identity('agent-0');
    for (var i = 0; i < 100; i++) {
      expect(presentation.identity('agent-0'), same(first));
    }
    presentation.event(
      RaftEvent('agent:activity', {
        'agentId': 'agent-1',
        'activity': 'working',
        'serverSeq': 1,
      }),
    );
    expect(presentation.identity('agent-0'), same(first));
    expect(first?.description, 'Public designer');
  });

  test('one activity update examines only its observed sender', () async {
    final (w, directory) = await _directory();
    final presentation = _ObservedPresentation(w, directory);
    addTearDown(presentation.dispose);
    final notifications = <int, int>{};
    for (var i = 0; i < 20; i++) {
      presentation.presenceOf('agent-$i').addListener(() {
        notifications.update(i, (value) => value + 1, ifAbsent: () => 1);
      });
    }
    presentation.reads.clear();
    presentation.event(
      RaftEvent('agent:activity', {
        'agentId': 'agent-3',
        'activity': 'thinking',
        'serverSeq': 2,
      }),
    );
    expect(presentation.display('agent-3')?.activity, 'thinking');
    expect(notifications, {3: 1});
    expect(presentation.reads.toSet(), {'agent-3'});
    expect(presentation.reads.length, lessThanOrEqualTo(2));
  });

  test(
    'unrelated workspace notifications do no sender presence work',
    () async {
      final (w, directory) = await _directory();
      final presentation = _ObservedPresentation(w, directory);
      addTearDown(presentation.dispose);
      presentation.presenceOf('agent-0');
      presentation.reads.clear();
      for (var i = 0; i < 20; i++) {
        w.notifyListeners();
      }
      expect(presentation.reads, isEmpty);
    },
  );

  test(
    'external expiry watches observed senders and keeps its deadline',
    () async {
      final (w, directory) = await _directory();
      final start = DateTime.utc(2026, 10, 24);
      w.entityDirectory.agentUpdateReceiver()({
        'id': 'agent-0',
        'runtime': 'external',
        'lastSeenAt': start.toIso8601String(),
      });
      fakeAsync((async) {
        final presentation = MessageAgentPresentation(
          w,
          directory,
          clock: async.getClock(start).now,
        );
        var changes = 0;
        expect(presentation.externalExpiry, isNull);
        presentation.presenceOf('agent-0').addListener(() => changes++);
        final timer = presentation.externalExpiry;
        expect(timer?.isActive, isTrue);
        expect(presentation.display('agent-0')?.online, isTrue);
        w.notifyListeners();
        presentation.event(
          RaftEvent('agent:activity', {
            'agentId': 'agent-1',
            'activity': 'thinking',
          }),
        );
        expect(presentation.externalExpiry, same(timer));
        async.elapse(const Duration(seconds: 119));
        expect(changes, 0);
        async.elapse(const Duration(seconds: 1));
        expect(changes, 1);
        expect(presentation.display('agent-0')?.online, isFalse);
        expect(presentation.externalExpiry, isNull);
        async.elapse(const Duration(minutes: 10));
        expect(changes, 1);
        presentation.dispose();
      });
    },
  );

  test(
    'metadata updates preserve other senders and revocation cancels expiry',
    () async {
      final (w, directory) = await _directory();
      final presentation = MessageAgentPresentation(w, directory);
      addTearDown(presentation.dispose);
      final first = presentation.identity('agent-0');
      final other = presentation.identity('agent-1');
      w.entityDirectory.agentUpdateReceiver()({
        'id': 'agent-0',
        'runtime': 'external',
        'lastSeenAt': DateTime.now().toIso8601String(),
        'description': 'Updated description',
      });
      expect(
        presentation.identity('agent-0')?.description,
        'Updated description',
      );
      expect(first?.description, 'Public designer');
      expect(presentation.identity('agent-1'), same(other));
      presentation.presenceOf('agent-0');
      expect(presentation.externalExpiry?.isActive, isTrue);
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      w.notifyListeners();
      expect(presentation.identity('agent-0'), isNull);
      expect(presentation.display('agent-0'), isNull);
      expect(presentation.externalExpiry, isNull);
    },
  );
}
