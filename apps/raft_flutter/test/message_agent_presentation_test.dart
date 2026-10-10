import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';

import 'message_presentation_test.dart' show fixture;

Future<void> accepted(MessageReferenceDirectory directory) async {
  for (var i = 0; i < 100 && directory.loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(directory.loading, false);
}

/// Waits for an in-place revalidation (agents read) to be accepted.
Future<void> revalidated(
  MessageReferenceDirectory directory,
  int before,
) async {
  for (var i = 0; i < 100 && directory.acceptedRevision == before; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(directory.acceptedRevision, isNot(before));
  expect(directory.loading, false);
}

const agent = {
  'id': 'agent',
  'name': 'Cindy',
  'status': 'active',
  'runtime': 'claude-code',
  'model': 'claude-sonnet-4-6',
  'description': 'Public designer',
};
void main() {
  test(
    'REST normalization and terminal socket activity use distinct admissions',
    () async {
      final (w, transport) = await fixture('owner');
      addTearDown(w.dispose);
      transport.routes['GET /agents'] = (_) => [agent];
      transport.routes['GET /servers/s1/members'] = (_) => [];
      final directory = MessageReferenceDirectory(w);
      final presentation = MessageAgentPresentation(w, directory);
      addTearDown(() {
        presentation.dispose();
        directory.dispose();
      });
      await accepted(directory);
      expect(presentation.identity('agent')?.description, 'Public designer');
      expect(presentation.display('agent')?.activity, 'working');
      presentation.event(
        RaftEvent('agent:activity', {
          'agentId': 'agent',
          'serverId': 's1',
          'serverSeq': 2,
          'activity': 'offline',
        }),
      );
      expect(presentation.display('agent')?.activity, 'offline');
      presentation.event(
        RaftEvent('agent:activity', {
          'agentId': 'agent',
          'serverId': 's1',
          'serverSeq': 1,
          'activity': 'working',
        }),
      );
      expect(presentation.display('agent')?.activity, 'offline');
      presentation.event(
        RaftEvent('agent:activity', {
          'agentId': 'agent',
          'serverId': 'other',
          'serverSeq': 3,
          'activity': 'working',
        }),
      );
      expect(presentation.display('agent')?.activity, 'offline');
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      w.notifyListeners();
      expect(presentation.identity('agent'), null);
      expect(presentation.display('agent'), null);
    },
  );
  test('revalidation keeps identities; late REST cannot replace a newer socket activity or a revoked directory', () async {
    final (w, transport) = await fixture('owner');
    addTearDown(w.dispose);
    transport.routes['GET /agents'] = (_) => [agent];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    final directory = MessageReferenceDirectory(w);
    final presentation = MessageAgentPresentation(w, directory);
    addTearDown(() {
      presentation.dispose();
      directory.dispose();
    });
    await accepted(directory);
    final response = Completer<dynamic>();
    transport.routes['GET /agents'] = (_) => response.future;
    final before = directory.acceptedRevision;
    directory.refresh();
    // Stale-while-revalidate: nothing is withdrawn while the read runs.
    expect(directory.loading, false);
    expect(presentation.identity('agent')?.description, 'Public designer');
    expect(presentation.display('agent')?.activity, 'working');
    presentation.event(
      RaftEvent('agent:activity', {
        'agentId': 'agent',
        'serverId': 's1',
        'serverSeq': 5,
        'activity': 'offline',
      }),
    );
    expect(presentation.display('agent')?.activity, 'offline');
    response.complete([agent]);
    await revalidated(directory, before);
    expect(presentation.display('agent')?.activity, 'offline');
    final stale = Completer<dynamic>();
    transport.routes['GET /agents'] = (_) => stale.future;
    directory.refresh();
    w.revokeServer('s1');
    expect(presentation.identity('agent'), null);
    stale.complete([agent]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(presentation.identity('agent'), null);
  });
  test('reconnect reloads and resets sequence; external seen is monotonic across REST', () async {
    final (w, transport) = await fixture('owner');
    addTearDown(w.dispose);
    final old = DateTime.now().subtract(const Duration(minutes: 3));
    var row = <String, dynamic>{
      ...agent,
      'runtime': 'external',
      'lastSeenAt': old.toIso8601String(),
    };
    transport.routes['GET /agents'] = (_) => [row];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    final directory = MessageReferenceDirectory(w);
    final presentation = MessageAgentPresentation(w, directory);
    addTearDown(() {
      presentation.dispose();
      directory.dispose();
    });
    await accepted(directory);
    expect(presentation.display('agent')?.online, false);
    final seen = DateTime.now();
    presentation.event(
      RaftEvent('agent:seen', {
        'agentId': 'agent',
        'lastSeenAt': seen.toIso8601String(),
      }),
    );
    expect(presentation.display('agent')?.online, true);
    presentation.event(
      RaftEvent('agent:seen', {
        'agentId': 'agent',
        'lastSeenAt': old.toIso8601String(),
      }),
    );
    expect(presentation.identity('agent')?.lastSeenAt, seen);
    final before = directory.acceptedRevision;
    directory.refresh();
    expect(presentation.identity('agent')?.lastSeenAt, seen);
    await revalidated(directory, before);
    expect(presentation.identity('agent')?.lastSeenAt, seen);
    presentation.event(
      RaftEvent('agent:activity', {
        'agentId': 'agent',
        'serverSeq': 9,
        'activity': 'error',
      }),
    );
    expect(presentation.display('agent')?.activity, 'error');
    row = {...row, 'activity': 'online'};
    final reads = transport.calls
        .where((call) => call.path == '/agents')
        .length;
    final reconnect = directory.acceptedRevision;
    presentation.event(RaftEvent('connected', {}));
    // Reconnect revalidates in place: the avatar badge is not withdrawn.
    expect(presentation.display('agent')?.activity, 'error');
    await revalidated(directory, reconnect);
    expect(
      transport.calls.where((call) => call.path == '/agents').length,
      reads + 1,
    );
    presentation.event(
      RaftEvent('agent:activity', {
        'agentId': 'agent',
        'serverSeq': 1,
        'activity': 'thinking',
      }),
    );
    expect(presentation.display('agent')?.activity, 'thinking');
  });
}
