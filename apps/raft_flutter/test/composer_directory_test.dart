import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/composer_directory.dart';
import 'package:raft_flutter/features/message_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

Future<void> settled() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets(
      'mention avatar follows borrowed activity and revocation $family/$dark',
      (tester) async {
        final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
        const agent = {
          'id': 'agent',
          'name': 'Cindy',
          'status': 'active',
          'activity': 'working',
          'runtime': 'codex',
        };
        a.routes['GET /agents'] = (_) => [agent];
        a.routes['GET /servers/s1/members'] = (_) => [];
        a.routes['GET /channels/c1/members'] = (_) => {
          'humans': [],
          'agents': [agent],
        };
        a.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
        final references = MessageReferenceDirectory(w);
        final activity = MessageAgentPresentation(w, references);
        final directory = ComposerDirectory(w, agentPresentation: activity);
        addTearDown(() {
          directory.dispose();
          activity.dispose();
          references.dispose();
          w.dispose();
        });
        directory.request('@');
        for (var i = 0; i < 40 && directory.people.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 5));
        }
        final candidate = directory.people.single;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: candidate.avatar),
          ),
        );
        expect(
          tester.widget<RaftAvatar>(find.byType(RaftAvatar)).presence?.activity,
          RaftAvatarActivity.working,
        );
        final reads = a.calls.length;
        activity.event(
          RaftEvent('agent:activity', {
            'agentId': 'agent',
            'serverId': 's1',
            'serverSeq': 2,
            'activity': 'offline',
          }),
        );
        await tester.pump();
        expect(
          tester.widget<RaftAvatar>(find.byType(RaftAvatar)).presence?.activity,
          RaftAvatarActivity.offline,
        );
        expect(a.calls.length, reads);
        activity.event(
          RaftEvent('agent:activity', {
            'agentId': 'agent',
            'serverId': 's1',
            'serverSeq': 1,
            'activity': 'working',
          }),
        );
        await tester.pump();
        expect(
          tester.widget<RaftAvatar>(find.byType(RaftAvatar)).presence?.activity,
          RaftAvatarActivity.offline,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: candidate.mutedAvatar),
          ),
        );
        final muted = tester.widget<RaftAvatar>(find.byType(RaftAvatar));
        expect(muted.presence, null);
        expect(muted.muted, true);
        w.server = RaftRecord({'id': 's1', 'role': 'guest'});
        w.notifyListeners();
        await tester.pump();
        expect(find.byType(RaftAvatar), findsNothing);
        expect(directory.people, isEmpty);
        await tester.pumpWidget(const SizedBox());
        expect(activity.ended, false);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('private roster is read when the channel opens, member-scoped, and false flag never requests resource directories', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    w.channel = RaftChannel({'id': 'c1', 'type': 'private', 'joined': true});
    a.routes['GET /channels/c1/members'] = (_) => {
      'humans': [
        {'id': 'human', 'name': 'same'},
      ],
      'agents': [
        {'id': 'agent', 'name': 'same'},
      ],
    };
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'composer_resource_references_v0', 'enabled': false},
      ],
    };
    final directory = ComposerDirectory(w);
    addTearDown(directory.dispose);
    // Nothing on the construction frame; Source reads the roster as a
    // secondary load once the channel is open, not on the first `@`.
    expect(a.calls.where((r) => r.path.contains('/members')), isEmpty);
    expect(directory.people, isEmpty);
    directory.request('#');
    await settled();
    expect(directory.people.map((p) => '${p.type}:${p.id}'), [
      'user:human',
      'agent:agent',
    ]);
    expect(directory.people.every((p) => p.inChannel), isTrue);
    directory.request('@');
    await settled();
    expect(
      a.calls.where((r) => r.path == '/channels/c1/members'),
      hasLength(1),
    );
    expect(
      a.calls.any(
        (r) => r.path == '/servers/s1/members' || r.path == '/agents',
      ),
      isFalse,
    );
    expect(
      a.calls.any(
        (r) => r.path.endsWith('/machines') || r.path.endsWith('/apps'),
      ),
      isFalse,
    );
  });
  test('late roster cannot restore identities after role loss', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    final response = Completer<Map<String, dynamic>>();
    a.routes['GET /channels/c1/members'] = (_) => response.future;
    final directory = ComposerDirectory(w);
    addTearDown(directory.dispose);
    directory.request('@');
    await settled();
    w.server = RaftRecord({'id': 's1', 'role': 'guest'});
    w.setError(null);
    response.complete({
      'humans': [
        {'id': 'secret', 'name': 'hidden'},
      ],
      'agents': [],
    });
    await settled();
    expect(directory.people, isEmpty);
    expect(a.calls.any((r) => r.path == '/servers/s1/members'), isFalse);
  });
  test('enabled resource references insert canonical targets without notifying a person', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    a.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
    a.routes['GET /agents'] = (_) => [];
    a.routes['GET /servers/s1/members'] = (_) => [];
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'composer_resource_references_v0', 'enabled': true},
      ],
    };
    a.routes['GET /servers/s1/machines'] = (_) => [
      {'id': 'machine-id', 'isComputer': true, 'name': 'Computer [A]'},
    ];
    a.routes['GET /servers/s1/apps'] = (_) => {
      'apps': [
        {'appId': 'system.test', 'displayName': 'Test app'},
      ],
    };
    final directory = ComposerDirectory(w);
    addTearDown(directory.dispose);
    directory.request('@');
    await settled();
    expect(
      directory.people.where((p) => p.type == 'computer').single.insertion,
      r'[@Computer \[A\]](<computer:machine-id>)',
    );
    expect(
      directory.people.where((p) => p.type == 'app').single.insertion,
      '[@Test app](<app:system.test>)',
    );
    expect(directory.people.every((p) => !p.isMention), isTrue);
  });

  group('surface scope (Web MessageInput mentionChannelId)', () {
    Map<String, dynamic> agent(String id) => {
      'id': id,
      'name': id,
      'status': 'active',
      'runtime': 'codex',
    };
    Map<String, dynamic> human(String id) => {
      'id': id,
      'userId': id,
      'name': id,
    };
    final members = [for (var i = 0; i < 8; i++) 'm$i'];

    Future<(WorkspaceController, MessageAdapter)> setup({
      required String type,
      bool thread = false,
      String mainType = 'channel',
    }) async {
      final (w, a) = await fixture('owner');
      addTearDown(w.dispose);
      final source = RaftChannel({
        'id': 'c1',
        'name': 'source',
        'type': type,
        'joined': true,
      });
      final main = RaftChannel({
        'id': 'cx',
        'name': 'main',
        'type': mainType,
        'joined': true,
      });
      w.channels = type == 'dm' ? [main] : [source, main];
      w.dms = type == 'dm' ? [source] : [];
      w.channel = thread ? main : source;
      if (thread) {
        w.messageDomain.ledger.switchServer('s1');
        w.messageDomain.state.threadParent = RaftMessage({
          'id': 'parent',
          'channelId': 'c1',
          'seq': 1,
          'senderType': 'user',
          'senderId': 'alice',
          'content': 'Parent',
        });
        w.threadChannelId = 'thread-c1';
        w.messageDomain.ledger.ingest([
          for (final (i, id) in ['m3', 'm5'].indexed)
            {
              'id': 'r$i',
              'channelId': 'thread-c1',
              'seq': i + 1,
              'senderType': 'agent',
              'senderId': id,
              'content': 'reply',
            },
        ], expectedGeneration: w.messageDomain.ledger.generation);
      }
      a.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      // The server directory also holds people outside the source channel.
      a.routes['GET /agents'] = (_) => [
        ...members.map(agent),
        agent('outsider'),
      ];
      a.routes['GET /servers/s1/members'] = (_) => [human('alice')];
      a.routes['GET /channels/c1/members'] = (_) => {
        'humans': [human('alice')],
        'agents': members.map(agent).toList(),
      };
      a.routes['GET /channels/cx/members'] = (_) => {
        'humans': [human('alice')],
        'agents': [agent('m0')],
      };
      return (w, a);
    }

    List<String> ids(ComposerDirectory d, {required bool inChannel}) => [
      for (final p in d.people)
        if (p.isMention && p.inChannel == inChannel) p.id,
    ];

    Future<ComposerDirectory> open(WorkspaceController w, {bool thread = false}) async {
      final directory = ComposerDirectory(w, thread: thread);
      addTearDown(directory.dispose);
      // The server-scoped author directory a mounted workspace has loaded.
      await w.entityDirectory.refresh(WorkspaceEntityKind.agents);
      await w.entityDirectory.refresh(WorkspaceEntityKind.members);
      directory.request('@');
      await settled();
      directory.request('@');
      await settled();
      return directory;
    }

    test('public channel: roster is in channel, other server agents are not', () async {
      final (w, _) = await setup(type: 'channel');
      final d = await open(w);
      expect(ids(d, inChannel: true).toSet(), {'alice', ...members});
      expect(ids(d, inChannel: false), ['outsider']);
    });

    test('DM is not member-scoped: server people stay available, peers in channel', () async {
      final (w, _) = await setup(type: 'dm');
      final d = await open(w);
      expect(ids(d, inChannel: true).toSet(), {'alice', ...members});
      expect(ids(d, inChannel: false), ['outsider']);
    });

    test('joint channel offers only its own roster', () async {
      final (w, _) = await setup(type: 'joint');
      final d = await open(w);
      expect(ids(d, inChannel: true).toSet(), {'alice', ...members});
      expect(ids(d, inChannel: false), isEmpty);
    });

    test('thread over a public channel reads the source roster and ranks recent speakers', () async {
      final (w, a) = await setup(type: 'channel', thread: true);
      final d = await open(w, thread: true);
      expect(ids(d, inChannel: true).toSet(), {'alice', ...members});
      expect(ids(d, inChannel: false), ['outsider']);
      expect({
        for (final p in d.people)
          if (p.threadRank != null) p.id: p.threadRank,
      }, {'m5': 0, 'm3': 1});
      expect(
        a.calls.where((r) => r.path == '/channels/c1/members'),
        hasLength(1),
      );
    });

    test('thread over a private/joint channel stays member-scoped even when the main pane is public', () async {
      for (final type in ['private', 'joint']) {
        final (w, _) = await setup(type: type, thread: true);
        final d = await open(w, thread: true);
        expect(ids(d, inChannel: true).toSet(), {'alice', ...members});
        expect(ids(d, inChannel: false), isEmpty);
      }
    });

    test('thread over a DM keeps the DM scope and does not reorder by recency', () async {
      final (w, _) = await setup(type: 'dm', thread: true);
      final d = await open(w, thread: true);
      expect(ids(d, inChannel: true).toSet(), {'alice', ...members});
      expect(d.people.every((p) => p.threadRank == null), isTrue);
    });

    test('thread with an unresolved source channel suggests nobody', () async {
      final (w, _) = await setup(type: 'channel', thread: true);
      w.messageDomain.state.threadParent = RaftMessage({
        'id': 'parent',
        'channelId': 'unknown',
        'seq': 1,
        'content': 'Parent',
      });
      final d = await open(w, thread: true);
      expect(d.people, isEmpty);
    });
  });
}
